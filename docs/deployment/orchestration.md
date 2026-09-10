# Orchestration — `carlysctl`

Ce document décrit ce que le serveur fait **tout seul**, ce qu'il refuse de
faire sans qu'on le lui dise, et comment regarder ce qu'il a fait.

Il suppose un serveur déjà mis en route :
[docs/deployment/mise-en-route-serveur.md](mise-en-route-serveur.md).

---

## 1. En cinq lignes

Le serveur portait quatre scripts justes mais séparés — `setup`, `deploy`,
`promote`, `backup`. Ce qui manquait n'était pas un cinquième : c'était **un
endroit** qui sache répondre à « est-ce que ça va ? » et « fais ce qu'il faut ».

`scripts/server/carlysctl` est cet endroit. Il route vers les quatre existants
sans rien leur recopier, et ajoute ce qu'aucun ne portait : l'état des lieux, la
mise à l'échelle, la réparation, la mise à jour. Une minuterie systemd le fait
passer **toutes les deux minutes**.

```bash
carlysctl status            # ce qui tourne, et comment ça va
carlysctl doctor            # ce qui manque sur la machine
carlysctl scale staging 3   # trois exemplaires d'API
carlysctl heal production   # relever ce qui est tombé
```

> Sur le serveur, le chemin complet est
> `/srv/carlys/repo/scripts/server/carlysctl`. Les exemples de ce document
> l'abrègent en `carlysctl`.

---

## 2. Ce qui tourne tout seul, et ce qui ne tourne pas

| | Automatique ? | Commandé par |
| --- | --- | --- |
| Relever un conteneur disparu, arrêté, ou « unhealthy » | **oui** | minuterie |
| Ajuster le nombre d'exemplaires d'API à la charge | **oui** | minuterie |
| Tenir l'amont Nginx à jour | **oui** | minuterie |
| Sauvegarder les bases | **oui** | cron, 3 h du matin |
| **Déployer une nouvelle version** | **non par défaut** | `CARLYS_AUTO_UPDATE` |

La dernière ligne est la seule qui demande une décision. Tant que
`CARLYS_AUTO_UPDATE=non` dans le `.env` d'un environnement — la valeur livrée —
**rien ne part** sans un geste humain. Le reste garde la pile debout ; ça ne
change pas la version qu'elle sert.

Pour tout arrêter :

```bash
systemctl disable --now carlys-supervision.timer
```

---

## 3. Regarder : `carlysctl status`

```
╔═ staging
   version                sha-a1b2c3d4e5f6 (depuis 3 h 12 min)
   conteneurs
     ✓ carlys_staging-postgres        running / healthy
     ✓ carlys_staging-redis           running / healthy
     ✓ carlys_staging-minio           running / healthy
     · carlys_staging-minio-init      exited  / sans-sonde
     ✓ carlys_staging-api-1           running / healthy
     ✓ carlys_staging-api-2           running / healthy
     ✓ carlys_staging-admin-1         running / healthy
   exemplaires API        2 en vie / 2 voulus (plafond 4, plage de 20)
   ports réels            3101 3104
   ports servis par nginx 3101 3104
   utilisateurs en ligne  37
   débit / latence        12.400 req/s, 84.2 ms en moyenne (sur 120 s)
   mise à jour auto       non (CARLYS_AUTO_UPDATE)
   réparations (1 h)      0 / 5
```

Trois lignes méritent une explication.

**`· … exited / sans-sonde` n'est pas une panne.** `minio-init` crée le bucket
puis se termine avec succès ; c'est une **tâche**, pas un service. `carlysctl`
les distingue par leur politique de redémarrage (`restart: 'no'` dans le
compose), pas par une liste de noms qui périmerait au prochain service ajouté.

**`ports réels` contre `ports servis par nginx`.** C'est la panne la plus
sournoise de cette architecture : les conteneurs vont bien, la supervision est
verte, et Nginx envoie du trafic à des ports que plus personne n'écoute. Quand
les deux listes divergent, `status` affiche une ligne `⚠ ÉCART` et la commande
qui la corrige. Rien d'autre ne montre ce cas.

**`utilisateurs en ligne : inconnu`** n'est pas `0`. La mesure vient de Redis ;
si l'API ne l'atteint pas, elle le dit au lieu de rendre zéro — un zéro faux
ferait **réduire** la pile au moment précis où l'on a perdu la mesure.

---

## 4. La mise à l'échelle

### 4.1 Comment la cible est calculée

```
cible = max( ⌈utilisateurs en ligne / CARLYS_SCALE_USERS_PER_REPLICA⌉,
             ⌈requêtes par seconde / CARLYS_SCALE_RPS_PER_REPLICA⌉,
             1 )

si latence moyenne > CARLYS_SCALE_LATENCY_HIGH_MS  →  cible = max(cible, actuel + 1)

cible bornée à [CARLYS_SCALE_MIN, plafond]
```

**Le maximum, jamais la somme.** Utilisateurs en ligne et débit mesurent la
même charge de deux façons ; les additionner doublerait la pile pour un seul
pic.

**La latence ajoute UN cran, elle ne fixe pas la cible.** Elle ne dit pas
combien d'exemplaires il faut, elle dit que ceux qui tournent n'y arrivent pas.
Une pile qui rame sans que le débit l'explique — requêtes lentes, base sous
tension — a besoin d'aide, pas de tripler.

**Une mesure inconnue ne compte pas.** Au premier passage, il n'y a pas de
débit (il faut deux échantillons pour dériver un compteur). Cette absence ne
vaut pas « zéro requête par seconde », sans quoi la pile se réduirait à chaque
redémarrage du superviseur.

### 4.2 Les trois garde-fous, et pourquoi ils existent

Ce qui rend cette décision difficile n'est pas la formule, c'est
**l'oscillation**. Un superviseur qui suit la charge à la lettre ajoute un
exemplaire au premier pic, le retire au premier creux, et recommence : la pile
passe son temps à démarrer et arrêter des processus, chaque redémarrage coûte
un cache froid, et le service devient **plus lent** qu'avec un nombre fixe.

| Garde-fou | Défaut | Ce qu'il empêche |
| --- | --- | --- |
| Délai de garde | 300 s | deux changements coup sur coup |
| Patience à la baisse | 3 passages | retirer un exemplaire sur un creux passager |
| Plafond | `nproc`, borné par la plage de ports | une mesure folle qui asphyxie la machine |

La **patience est asymétrique**, et c'est voulu : un seul passage suffit pour
monter, trois pour descendre. Se tromper en ajoutant coûte de la mémoire ; se
tromper en retirant coûte des erreurs servies à de vrais utilisateurs.

Le **plafond** ne dépend d'aucune mesure. `nproc` par défaut, parce que l'API
est un processus Node, mono-thread pour le code utilisateur : au-delà d'un
exemplaire par cœur, ils se disputent le même processeur — on paie la mémoire
de chacun sans gagner de débit. Et jamais plus que la plage de ports :
au-delà, Docker échoue **en cours de route** (« all ports are allocated ») et
laisse la pile à moitié mise à l'échelle. `carlysctl` refuse donc avant
d'appeler Compose.

### 4.3 Les réglages

Tous dans le `.env` de l'environnement, tous facultatifs.

| Variable | Défaut | |
| --- | --- | --- |
| `CARLYS_SCALE_MIN` | 1 | plancher |
| `CARLYS_SCALE_MAX` | `nproc` | plafond, borné par la plage de ports |
| `CARLYS_SCALE_USERS_PER_REPLICA` | 250 | |
| `CARLYS_SCALE_RPS_PER_REPLICA` | 40 | |
| `CARLYS_SCALE_LATENCY_HIGH_MS` | 750 | au-delà, un cran de plus |
| `CARLYS_SCALE_COOLDOWN_SECONDS` | 300 | délai de garde, les deux sens |
| `CARLYS_SCALE_DOWN_PATIENCE` | 3 | passages d'accord avant de réduire |

Ces valeurs sont des **points de départ raisonnables, pas des vérités**. La
seule bonne façon de les régler est de regarder `carlysctl status` sous charge
réelle : si la latence monte alors que la pile est à son plafond, c'est le
plafond qu'il faut lever ; si elle reste basse à deux exemplaires sur quatre,
c'est `USERS_PER_REPLICA` qui est trop bas.

### 4.4 À la main

```bash
carlysctl scale staging 3          # fixe, et applique tout de suite
carlysctl autoscale staging        # dit ce qu'il ferait, ne fait rien
carlysctl autoscale staging --appliquer
```

`carlysctl autoscale` sans `--appliquer` est la commande à taper avant de
toucher aux réglages : elle affiche la décision, la raison, et les mesures qui
l'ont produite.

---

## 5. La réparation

Un passage de `heal` regarde chaque conteneur de la pile et agit sur trois cas :

- **disparu ou arrêté** → `docker compose up -d`, qui recrée ce qui manque en
  respectant les dépendances du compose (ce qu'un `docker start` conteneur par
  conteneur ne saurait pas faire) ;
- **« unhealthy » deux passages de suite** → `docker restart`. Deux passages,
  parce qu'une sonde qui échoue une fois arrive : redémarrage de PostgreSQL,
  pic de charge, requête lente. `up -d` ne suffirait pas ici — le conteneur
  **tourne**, donc Compose le considère à jour ;
- **moins d'exemplaires d'API que le `.env` n'en déclare** → même traitement.

Après quoi l'amont Nginx est régénéré — mais **seulement une fois les
conteneurs sains**. Sans cette attente, l'exemplaire relevé n'entrait jamais
dans l'amont : le passage suivant retrouvait le même écart, relançait `up -d`,
et réécrivait le même amont incomplet. Pile réparée, trafic jamais rétabli.

### Savoir renoncer

**C'est la partie qui compte.** Un conteneur qui meurt au démarrage —
migration incompatible, secret manquant, image corrompue — remourra au
redémarrage suivant. Le relancer en boucle ne répare rien : cela consomme la
machine, noie le journal, et surtout **donne l'impression que quelqu'un s'en
occupe**, ce qui retarde le moment où un humain regarde.

Au-delà de `CARLYS_HEAL_MAX_PER_HOUR` (5) réparations dans l'heure, `carlysctl`
cesse d'agir et ne fait plus que le dire, avec les commandes de diagnostic.
`carlysctl status` affiche le compteur (`réparations (1 h)`).

---

## 6. La mise à jour automatique

**Les deux environnements ne se mettent pas à jour de la même façon**, et c'est
le point le plus important de ce document.

### Recette — elle suit une branche

`CARLYS_AUTO_UPDATE=oui` dans `/srv/carlys/staging/.env`. La recette suit alors
la tête de `CARLYS_UPDATE_BRANCH` (défaut `main`), **dès que les trois images de
ce commit existent dans le registre**.

Un commit dont la construction a échoué ne déclenche donc rien : la recette
reste sur ce qu'elle a et réessaiera au passage suivant. C'est ce qui empêche
de déployer un commit rejeté par la CI.

### Production — elle suit la RECETTE, jamais une branche

`CARLYS_AUTO_UPDATE=oui` dans `/srv/carlys/production/.env`. La production
promeut alors le sha **qui tourne déjà en recette**, et seulement si :

1. il y a passé `CARLYS_PROMOTE_SOAK_MINUTES` (60 par défaut) ;
2. la recette est **saine maintenant** — tous ses exemplaires répondent 200 sur
   `/health/ready`. Un sha qui a passé sa maturation en répondant 503 n'a rien
   prouvé ;
3. l'image admin `-prod` existe, donc la garde légale est passée.

C'est la règle du dépôt — *on construit une fois, on déploie deux fois* —
appliquée sans humain au clavier. Une production qui suivrait une branche
déploierait du code que personne n'a vu tourner.

La promotion passe par `promote.sh`, **jamais** par `deploy.sh` : c'est lui qui
porte les vérifications propres à la production et le message qui explique quoi
faire quand l'image `-prod` manque. Les recopier ailleurs les ferait diverger.

### Ce que l'interrupteur décide, et ce qu'il ne décide pas

`CARLYS_AUTO_UPDATE` décide **qui appuie sur le bouton**, pas si le filet est
tendu. Les vérifications de `deploy.sh` (images présentes, migration avant
bascule, attente de santé bornée, retour arrière automatique) et celles de
`promote.sh` ne sont jamais court-circuitées.

L'accord donné d'avance par l'orchestrateur nomme **le sha**, pas « oui » : un
accord général signerait n'importe quelle promotion, y compris celle d'un sha
que personne n'a examiné. Si l'état a changé entre la décision et son
exécution, les deux valeurs diffèrent et tout s'arrête.

---

## 7. Les mesures, et d'où elles viennent

L'API expose `/metrics` au format Prometheus. `carlysctl` interroge **chaque
exemplaire séparément**, jamais à travers Nginx : passer par Nginx atteindrait
un exemplaire au hasard, et on lirait le débit d'un tiers de la pile en croyant
lire celui de la pile.

| Série | Portée | |
| --- | --- | --- |
| `carlys_api_online_users` | **globale** | utilisateurs distincts vus sur la fenêtre |
| `carlys_api_presence_up` | globale | 1 = la mesure vient d'aboutir |
| `carlys_api_online_users_window_seconds` | globale | largeur de la fenêtre (300 s) |
| `carlys_api_http_requests_total` | par processus | additionnée sur les exemplaires |
| `carlys_api_http_request_duration_seconds` | par processus | additionnée |
| `carlys_api_http_requests_in_flight` | par processus | |

La présence est **globale** parce qu'elle est comptée dans Redis, par
HyperLogLog, avec une clé par minute d'horloge. C'est indispensable : c'est
cette valeur qui pilote la mise à l'échelle. Comptée en mémoire, chaque
exemplaire ne verrait que sa part du trafic et la somme dépendrait du nombre
d'exemplaires — la mesure qui décide de la taille de la pile varierait avec la
taille de la pile. Elle n'est donc **jamais additionnée** : `carlysctl` prend
la valeur d'un exemplaire dont `presence_up` vaut 1.

Les compteurs HTTP, eux, sont par processus **volontairement** : la répartition
entre exemplaires est une information — elle montre qu'un seul d'entre eux
encaisse tout.

### En production, `METRICS_TOKEN` est obligatoire

Sans lui, `/metrics` répond comme s'il n'existait pas — y compris à
`carlysctl`. La supervision continuerait de voir la **santé** des conteneurs,
mais la mise à l'échelle n'aurait plus aucune mesure et resterait figée.

Le port de l'API n'écoute que sur la boucle locale et Nginx refuse `/metrics`
(`deny all`) : ce jeton protège l'accès **depuis la machine**, pas depuis
internet.

---

## 8. L'amont Nginx est engendré

Les vhosts de `infrastructure/nginx/` déclarent l'amont de l'admin et celui de
MinIO, mais **pas** celui de l'API.

L'API tourne en plusieurs exemplaires ; Docker attribue à chacun un port
**libre** pris dans la plage réservée par le `.env`
(`CARLYS_API_HOST_PORT` … `CARLYS_API_HOST_PORT_LAST`), sans garantie d'ordre ni
de contiguïté — mesuré : à quatre exemplaires sur une plage de dix,
l'attribution était 3403, 3404, 3406, 3407. Une liste écrite à la main serait
fausse dès la première mise à l'échelle, et fausse **en silence**.

`carlysctl` lit donc la liste chez Docker et écrit :

```
/etc/nginx/conf.d/carlys-<env>-api-upstream.conf
```

Ce fichier est **engendré** : toute modification manuelle disparaîtra au
prochain déploiement ou à la prochaine mise à l'échelle.

Trois garanties valent d'être connues :

- **jamais d'amont vide.** Un bloc `upstream` sans `server` est une
  configuration invalide ; écraser un amont sain par du vide couperait le
  service au lieu de le réparer. S'il n'y a aucun exemplaire, le fichier est
  laissé **intact** et le refus est dit ;
- **jamais d'amont refusé laissé en place.** L'ancien est sauvegardé, le
  nouveau écrit, `nginx -t` joué ; en cas d'échec l'ancien est restauré. Sans
  cela, le prochain `systemctl reload nginx` d'un tiers échouerait sans rapport
  avec lui ;
- **pas de rechargement inutile.** Si le contenu n'a pas changé, rien n'est
  écrit et Nginx n'est pas rechargé.

**Conséquence à connaître** : tant que ce fichier n'existe pas, `nginx -t`
échoue par `[emerg] host not found in upstream "carlys_api_production"`.
`setup.sh` en pose une version à un seul exemplaire dès l'installation, avant
même de démarrer Nginx.

---

## 9. La minuterie

```bash
systemctl list-timers carlys-supervision.timer   # prochaine passe
journalctl -u carlys-supervision.service -f      # ce qu'elle fait
systemctl start carlys-supervision.service       # une passe tout de suite
systemctl disable --now carlys-supervision.timer # tout arrêter
```

**Deux minutes.** Plus court n'avancerait aucune décision : elles sont toutes
amorties par leurs propres garde-fous. Plus long serait le délai maximal entre
le moment où un conteneur tombe et celui où quelqu'un s'en aperçoit — Docker
relance de lui-même ce qui porte `restart: unless-stopped`, mais rien ne recrée
un conteneur disparu, ne redémarre un conteneur « unhealthy » qui tourne
toujours, ni ne corrige un amont Nginx devenu faux.

**L'ordre d'une passe n'est pas négociable** :

1. **réparer**, d'abord. Mesurer une pile à moitié tombée donne un débit qui ne
   veut rien dire, et la mise à l'échelle en tirerait la conclusion inverse de
   la bonne — moins de trafic reçu parce que moins d'exemplaires pour le
   recevoir, donc « réduisons » ;
2. **mettre à l'échelle**, sur une pile entière ;
3. **mettre à jour**, en dernier : un déploiement recrée les conteneurs et
   rendrait caduques les deux étapes précédentes.

La passe prend le **verrou d'environnement** pour les étapes 1 et 2, puis le
relâche avant l'étape 3 — qui délègue à `deploy.sh` ou `promote.sh`, deux
scripts séparés qui le prennent pour eux-mêmes. Une supervision ne peut donc
pas tomber en plein milieu d'un déploiement tapé à la main : elle refuse et le
dit.

---

## 10. Quand ça ne va pas

| Symptôme | Cause la plus fréquente |
| --- | --- |
| `status` affiche `⚠ ÉCART nginx ↔ réalité` | l'amont n'a pas suivi un changement : `carlysctl heal <env>` |
| `mesures : aucun exemplaire ne rend /metrics` | en production, `METRICS_TOKEN` absent du `.env` |
| `utilisateurs en ligne : inconnu` | l'API n'atteint pas Redis — `status` montre le conteneur |
| `PLAFOND DE RÉPARATIONS ATTEINT` | une panne qui revient à chaque redémarrage ; lire `docker compose logs` |
| `débit / latence : pas encore mesurable` | premier passage — un débit se dérive de deux échantillons |
| La pile ne grandit pas alors que la charge monte | `carlysctl autoscale <env>` dit pourquoi : `delai-de-garde`, ou plafond atteint |
| `carlysctl` dit « un déploiement est déjà en cours » | une passe de supervision ou un `deploy.sh` tient le verrou — `fuser -v /srv/carlys/<env>/.lock` |
| La mise à jour automatique ne part jamais | `CARLYS_AUTO_UPDATE`, ou en production la maturation pas encore écoulée — `carlysctl update <env>` dit lequel |

---

## À lire à côté

- [mise-en-route-serveur.md](mise-en-route-serveur.md) — installer le serveur
- [../../infrastructure/deployment/README.md](../../infrastructure/deployment/README.md) — la stratégie de déploiement
- [../../infrastructure/nginx/README.md](../../infrastructure/nginx/README.md) — les vhosts
- [../security/reverse-proxy.md](../security/reverse-proxy.md) — la chaîne de proxys et l'adresse du client
