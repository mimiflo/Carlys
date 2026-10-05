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
carlysctl doctor            # ce qui manque : machine, Nginx, et chaque .env
carlysctl scale staging 3   # trois exemplaires d'API
carlysctl heal production   # relever ce qui est tombé
carlysctl prune --essai     # ce qu'un élagage d'images supprimerait
```

> Sur le serveur, le chemin complet est
> `/srv/carlys/repo/scripts/server/carlysctl`. Les exemples de ce document
> l'abrègent en `carlysctl`.

---

## 2. Ce qui tourne tout seul, et ce qui ne tourne pas

|                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Automatique ?      | Commandé par         |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------ | -------------------- |
| Relever un conteneur disparu, arrêté, ou « unhealthy »                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | **oui**            | minuterie            |
| Ajuster le nombre d'exemplaires d'API à la charge                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | **oui**            | minuterie            |
| Tenir l'amont Nginx à jour                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | **oui**            | minuterie            |
| Élaguer images, couches pendantes et cache de construction de plus d'une semaine à chaque passe (le filet de retour arrière est gardé ; jamais les volumes)                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | **oui**            | minuterie            |
| Effacer les photos de repas orphelines du bucket privé, une fois par jour (`_photos.sh` ; à la main : `carlysctl meal-photos-sweep <env> [--a-blanc]`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | **oui**            | minuterie            |
| Importer la table d'aliments CIQUAL, téléchargée et vérifiée par son empreinte, une fois par version (`_ciqual.sh` ; à la main : `carlysctl ciqual-import <env>`) | **oui**            | minuterie            |
| Effacer définitivement les comptes supprimés depuis plus de `CARLYS_ACCOUNT_PURGE_DAYS` jours (30 par défaut : le délai qu'annoncent la politique, les CGU et l'écran de suppression, à changer avec eux ; la liste complète des textes qui l'écrivent est dans `SECURITY.md`, « Données personnelles »), photos privées comprises, et les événements de paiement anonymes jamais appliqués reçus depuis plus de 90 jours, une fois par jour (`_purge_comptes.sh` ; à la main : `carlysctl deleted-accounts-purge <env> [--a-blanc] [--compte <uuid>] [--compte-actif <uuid>]`, voir « Effacement immédiat sur demande » ci-dessous) | **oui**            | minuterie            |
| Sauvegarder les bases **et les médias MinIO**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | **oui**            | cron, 3 h du matin   |
| **Déployer une nouvelle version**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | **non par défaut** | `CARLYS_AUTO_UPDATE` |

La dernière ligne est la seule qui demande une décision. Tant que
`CARLYS_AUTO_UPDATE=non` dans la configuration d'un environnement
(`infrastructure/server/config/<env>.conf`) — la valeur livrée —
**rien ne part** sans un geste humain. Le reste garde la pile debout ; ça ne
change pas la version qu'elle sert.

Pour tout arrêter :

```bash
systemctl disable --now carlys-supervision.timer
```

### Effacement immédiat sur demande

La politique de confidentialité (sections 6 et 7) promet un effacement
définitif sans attendre les 30 jours à qui l'écrit **avant** de supprimer
son compte, depuis l'adresse de ce compte. L'ordre n'est pas un détail : la
suppression réécrit l'adresse en `supprime+<uuid>@carlys.invalid`, vide le
nom et efface les identités Google ou Apple, et plus rien ne mène alors de
la personne à l'UUID que les commandes exigent.

**L'adresse d'expéditeur ne prouve rien.** L'en-tête `From` d'un courriel se
falsifie (il suffit que le domaine de la personne n'impose pas DMARC
`p=reject`), et `Reply-To` décide où part une réponse. Or la commande
supprime ET efface, tout de suite : plus de délai de 30 jours pour corriger
une erreur. Sans preuve, un tiers qui connaît l'adresse d'un membre ferait
effacer son compte. La preuve est donc celle de « Mot de passe oublié » :
la personne montre qu'elle LIT la boîte du compte, en renvoyant un code que
Carlys y a écrit. D'où la procédure :

1. **À réception de la demande**, dans le back-office, page Utilisateurs :
   chercher l'adresse de l'expéditeur, ouvrir la fiche, noter l'UUID (il est
   dans l'adresse de la page, `/users/<uuid>`) et l'adresse **telle que la
   fiche l'affiche**. Aucun compte à cette adresse : ne rien faire (voir la
   fin de cette section).
2. **Prouver la boîte, avant toute commande.** Tirer un code pour cette
   demande seule :

   ```bash
   openssl rand -hex 4
   ```

   L'envoyer dans un **nouveau** message, pas par « Répondre », à l'adresse
   notée sur la fiche, en demandant de le renvoyer pour confirmer
   l'effacement. N'agir que sur une réponse qui porte **ce** code. Sans
   réponse, ou avec un autre code, ne rien faire : si la demande était
   usurpée, la vraie personne vient d'en être avertie, et son compte n'a
   pas bougé.

3. **Compte encore actif** (le cas normal) : l'outil le supprime exactement
   comme l'appli (abonnement Stripe résilié, refus si Stripe ne l'a pas
   fait ; sortie de la ligue, des défis et du fil ; ligne d'audit
   `account.deleted_by_operator`), puis l'efface tout de suite.
   L'adresse ne se passe PAS en argument, que l'historique du shell de
   root garderait : `carlysctl` la demande au clavier, recopier celle de la
   fiche. Si ce n'est pas celle du compte (casse et espaces ignorés), rien
   n'est fait, code 2. Cette recopie garde d'une faute de frappe sur
   l'UUID ; elle ne prouve pas qui demande, c'est le code de l'étape 2 qui
   le prouve.

   ```bash
   carlysctl deleted-accounts-purge production --compte-actif <uuid> --a-blanc   # vérifier
   carlysctl deleted-accounts-purge production --compte-actif <uuid>
   ```

   Si la sortie annonce un abonnement App Store ou Play Store qui court
   encore, le dire à la personne dans la réponse : le serveur ne peut pas le
   résilier, seul le magasin le peut. Si Stripe n'a pas résilié, rien n'est
   supprimé : relancer un peu plus tard. Si la ligne d'audit n'a pas pu
   être écrite, le compte est supprimé mais PAS effacé : relancer avec
   `--compte <uuid>` une fois la base réparée.

4. **Compte déjà supprimé** entre la demande et l'intervention (la fiche
   `/users/<uuid>` affiche le statut `DELETED`), le code ayant été renvoyé :

   ```bash
   carlysctl deleted-accounts-purge production --compte <uuid> --a-blanc   # vérifier
   carlysctl deleted-accounts-purge production --compte <uuid>
   ```

   Un refus (`--compte` n'efface jamais un compte actif ou suspendu, et
   `--compte-actif` jamais un compte déjà supprimé) ou un échec (stockage
   des photos muet, le plus souvent) arrête `carlysctl` avec le message de
   la commande. Sur un échec, relancer une fois la cause réparée (sinon la
   purge quotidienne le reprendra au bout des 30 jours).

5. **Confirmer** l'effacement à la personne, à l'adresse de la fiche,
   celle qui a reçu le code.

Une demande reçue APRÈS la suppression ne peut être rattachée à aucun
compte : l'effacement se fait alors au bout des 30 jours, par la purge
quotidienne, ce que la réponse doit dire.

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

**`· … exited / sans-sonde` n'est pas une panne.** `minio-init` crée les deux
buckets (médias publics, photos de repas privées) puis se termine avec
succès ; c'est une **tâche**, pas un service. `carlysctl`
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

### 4.2 Les cinq garde-fous, et pourquoi ils existent

Ce qui rend cette décision difficile n'est pas la formule, c'est
**l'oscillation**. Un superviseur qui suit la charge à la lettre ajoute un
exemplaire au premier pic, le retire au premier creux, et recommence : la pile
passe son temps à démarrer et arrêter des processus, chaque redémarrage coûte
un cache froid, et le service devient **plus lent** qu'avec un nombre fixe.

| Garde-fou            | Défaut                                                                                                                                                                                                                                                                   | Ce qu'il empêche                                                                                                                            |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Délai de garde       | 300 s                                                                                                                                                                                                                                                                    | deux changements coup sur coup                                                                                                              |
| Patience à la baisse | 3 passages                                                                                                                                                                                                                                                               | retirer un exemplaire sur un creux passager                                                                                                 |
| Plafond              | `nproc`, borné par la plage de ports                                                                                                                                                                                                                                     | une mesure folle qui asphyxie la machine                                                                                                    |
| Travail en cours     | aucune descente tant qu'une requête, une réponse du coach ou une analyse de photo est en cours ou en file (`en_vol`, lu sur `/metrics` : requêtes HTTP plus `carlys_api_ai_work_open`, un tour du coach ou une analyse de photo de son admission à sa dernière écriture) | couper une réponse du coach en plein calcul (une à deux minutes sur processeur), y compris page quittée, où plus aucune requête ne la tient |
| Drainage             | 300 s (`CARLYS_SCALE_DRAIN_SECONDS`)                                                                                                                                                                                                                                     | arrêter un exemplaire qui a reçu du travail APRÈS la mesure                                                                                 |

**Le drainage** (`scale_drainer`, `_scale.sh`). La mesure ci-dessus date du
début du passage : une requête partie dans les secondes suivantes tombait avec
l'exemplaire. Une réduction se fait donc en quatre temps : choisir les
partants (les malades d'abord, puis les plus hauts numéros) ; les retirer de
l'amont Nginx, qui ne leur
confie plus rien et laisse finir ce qu'il leur a déjà confié ; attendre que
leur travail soit à zéro ; les arrêter **nous-mêmes**, puis seulement écrire
le nouveau nombre. Compose, à qui il ne reste que le bon nombre, n'a plus rien
à retirer : il ne peut donc pas en choisir un autre que celui qu'on a vidé.
Si le travail ne finit pas dans le délai, s'il ne se lit pas (`/metrics`
refusé), ou si un partant refuse de s'arrêter : l'amont est rétabli, le `.env`
garde l'ancien nombre, `carlysctl scale` rend 1, et le passage suivant
réessaiera.

**Le déploiement aussi laisse finir** (`deploy_attendre_ia`, `_scale.sh`).
Une bascule (`deploy.sh`, étape 7) recrée l'API : une réponse du coach en
route mourait avec l'ancien processus, et le téléphone affichait « Le coach a
besoin d'une connexion ». Le 5 octobre 2026, une poussée qui ne touchait que
l'application mobile a ainsi coupé une réponse : la recette suit
`development`, chaque poussée la redéploie. La bascule attend donc que
`carlys_api_ai_work_open` retombe à zéro sur les exemplaires en service, au
plus `CARLYS_DEPLOY_DRAIN_SECONDS` (120 s : une passe de supervision qui
déploie la recette puis la production doit tenir dans les 20 min que lui
accorde systemd), puis bascule quand même ; un
`/metrics` illisible ne la retient pas. L'exemplaire reste dans l'amont
pendant l'attente : seul, il sert encore tout le monde.

Changer le nombre ne recrée JAMAIS les exemplaires qui restent
(`up -d --no-recreate`) : le `.env` étant aussi l'`env_file` de l'API, y écrire
le nouveau nombre changeait la configuration de tous, et Compose les recréait
tous. Le 2 octobre 2026, une descente de 2 à 1 a ainsi recréé `api-1` et retiré
`api-2` en même temps, et tué la réponse du coach en cours.

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

Tous dans la configuration versionnée (`infrastructure/server/config/commun.conf`,
ou `<env>.conf` pour ce qui diffère — ADR 0017), tous facultatifs.

| Variable                         | Défaut  |                                      |
| -------------------------------- | ------- | ------------------------------------ |
| `CARLYS_SCALE_MIN`               | 1       | plancher                             |
| `CARLYS_SCALE_MAX`               | `nproc` | plafond, borné par la plage de ports |
| `CARLYS_SCALE_USERS_PER_REPLICA` | 250     |                                      |
| `CARLYS_SCALE_RPS_PER_REPLICA`   | 40      |                                      |
| `CARLYS_SCALE_LATENCY_HIGH_MS`   | 750     | au-delà, un cran de plus             |
| `CARLYS_SCALE_COOLDOWN_SECONDS`  | 300     | délai de garde, les deux sens        |
| `CARLYS_SCALE_DOWN_PATIENCE`     | 3       | passages d'accord avant de réduire   |

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

`CARLYS_AUTO_UPDATE=oui` dans `infrastructure/server/config/staging.conf`
(un commit, ADR 0017). La recette suit alors
la tête de `CARLYS_UPDATE_BRANCH` (défaut `development`), **dès que les trois images de
ce commit existent dans le registre**.

Un commit dont la construction a échoué ne déclenche donc rien : la recette
reste sur ce qu'elle a et réessaiera au passage suivant. C'est aussi ce qui
empêche de déployer un commit rejeté par la CI, parce que `images-publish`
ne pousse les étiquettes `sha-…` qu'une fois `api-ci`, `admin-ci`,
`images-ci` et `infra-ci` verts pour le code de ce commit (porte « La CI de ce commit est
verte », [`scripts/ci/verdict_ci.sh`](../../scripts/ci/verdict_ci.sh)). Un
commit rouge n'a aucune image d'application : ni la recette, ni `promote.sh`
ne peuvent le déployer. Cela vaut aussi pour un rattrapage ancien : un commit
dont l'exécution est sortie des 100 dernières est demandé par son sha, et un
verdict introuvable bloque au lieu de passer. Un commit du milieu d'une
poussée groupée, que la CI n'a jugé qu'à travers la tête de sa poussée, n'a
pas non plus de verdict à lui dès que le code qu'elle surveille a changé
depuis le dernier commit jugé : il bloque aussi. Si l'échec ne tenait pas au
code (registre tiers en panne), relancer la CI de ce commit puis
`images-publish`, ou lancer `images-publish` à la main avec son sha et la
case `ignorer_ci`.

### Production — elle suit la RECETTE, jamais une branche

`CARLYS_AUTO_UPDATE=oui` dans `infrastructure/server/config/production.conf`.
La production
promeut alors le sha **qui tourne déjà en recette**, et seulement si :

1. il y a passé `CARLYS_PROMOTE_SOAK_MINUTES` (60 par défaut) ;
2. la recette est **saine maintenant** — tous ses exemplaires répondent 200 sur
   `/health/ready`. Un sha qui a passé sa maturation en répondant 503 n'a rien
   prouvé ;
3. l'image admin `-prod` existe, donc la garde légale est passée.

C'est la règle du dépôt — _on construit une fois, on déploie deux fois_ —
appliquée sans humain au clavier. Une production qui suivrait une branche
déploierait du code que personne n'a vu tourner.

La promotion passe par `promote.sh`, **jamais** par `deploy.sh` : c'est lui qui
porte les vérifications propres à la production et le message qui explique quoi
faire quand l'image `-prod` manque. Les recopier ailleurs les ferait diverger.

### Un sha qui a échoué n'est jamais retenté

C'est le garde-fou le plus important du module, et il a manqué. Sans lui, un
sha dont le déploiement échoue est **retenté à chaque passe** — toutes les deux
minutes, indéfiniment : la cible reste la tête de la branche, et `DEPLOYED` est
resté au sha précédent, donc rien ne coupe le cycle.

Deux conséquences, la seconde pire que la première :

- une **migration cassée est rejouée sur la base** toutes les deux minutes.
  `deploy.sh` meurt alors sans rien basculer et sans écrire `DEPLOYED`, donc le
  cycle complet tient dans une seule passe et recommence aussitôt ;
- à chaque tour, la bascule recrée les conteneurs **avant** la vérification de
  santé, et l'amont Nginx n'est réécrit qu'après : le service rend 502 pendant
  toute l'attente puis tout le retour arrière — plusieurs minutes par tour.

Un sha qui a échoué est donc mis de côté, **définitivement pour ce sha**. Ce
n'est pas un délai de garde : réessayer ne répare rien, le code est le même. La
mise à jour repart d'elle-même au commit suivant, ou à la main :

```bash
carlysctl deploy staging <sha>     # forcer, en connaissance de cause
```

### La PREMIÈRE mise en production ne se fait jamais toute seule

`deploy.sh` n'a de retour arrière que s'il existe un sha précédent. Une
production qui n'a jamais rien hébergé n'en a pas : un échec de santé y
laisserait la pile debout sur un sha malade, sans filet, et sans personne au
clavier. C'est aussi le passage où les secrets, le domaine et les textes légaux
s'éprouvent pour de bon.

La mise à jour automatique s'abstient donc tant que `DEPLOYED` de la production
est vide, et le dit. Une fois le premier `carlysctl promote` fait à la main,
elle prend le relais.

### Ce que l'interrupteur décide, et ce qu'il ne décide pas

`CARLYS_AUTO_UPDATE` décide **qui appuie sur le bouton**, pas si le filet est
tendu. Les vérifications de `deploy.sh` (images présentes, migration avant
bascule, catalogues d'exercices et d'abonnement chargés avant bascule eux
aussi — le second bloquant seulement si un paiement pourrait être encaissé
sans rien accorder —, attente de santé bornée, retour arrière
automatique) et celles de `promote.sh` ne sont jamais
court-circuitées.

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

| Série                                      | Portée        |                                           |
| ------------------------------------------ | ------------- | ----------------------------------------- |
| `carlys_api_online_users`                  | **globale**   | utilisateurs distincts vus sur la fenêtre |
| `carlys_api_presence_up`                   | globale       | 1 = la mesure vient d'aboutir             |
| `carlys_api_online_users_window_seconds`   | globale       | largeur de la fenêtre (300 s)             |
| `carlys_api_http_requests_total`           | par processus | additionnée sur les exemplaires           |
| `carlys_api_http_request_duration_seconds` | par processus | additionnée                               |
| `carlys_api_http_requests_in_flight`       | par processus |                                           |

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

### `METRICS_TOKEN` est obligatoire — en RECETTE aussi

C'est contre-intuitif, donc la raison compte : le garde de `/metrics` ne
regarde pas le _nom_ de l'environnement, il regarde `NODE_ENV`. Or `NODE_ENV`
vaut `production` **dans les deux** `.env` — c'est voulu, la recette doit
échouer comme la production, sinon elle ne prouve rien.

Sans jeton, `/metrics` répond donc **404**, y compris à `carlysctl`. La
supervision continue de voir la **santé** des conteneurs, mais la mise à
l'échelle n'a plus aucune mesure et reste figée.

Le symptôme, tel qu'il est apparu sur le premier serveur migré :

```
   utilisateurs en ligne  inconnu (Redis illisible depuis l'API)
```

…alors que Redis répondait parfaitement. `carlysctl` comptait le corps de
l'erreur 404 comme une lecture réussie et accusait Redis. Il dit maintenant :

```
   mesures                /metrics REFUSE — code 404 sur 1 exemplaire(s)
                          METRICS_TOKEN absent du .env. Le garde répond 404 dès que
                          NODE_ENV=production — ce qui est le cas de la RECETTE aussi.
```

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

| Symptôme                                              | Cause la plus fréquente                                                                                       |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `status` affiche `⚠ ÉCART nginx ↔ réalité`            | l'amont n'a pas suivi un changement : `carlysctl heal <env>`                                                  |
| `mesures : aucun exemplaire ne rend /metrics`         | en production, `METRICS_TOKEN` absent du `.env`                                                               |
| `utilisateurs en ligne : inconnu`                     | l'API n'atteint pas Redis — `status` montre le conteneur                                                      |
| `PLAFOND DE RÉPARATIONS ATTEINT`                      | une panne qui revient à chaque redémarrage ; lire `docker compose logs`                                       |
| `débit / latence : pas encore mesurable`              | premier passage — un débit se dérive de deux échantillons                                                     |
| La pile ne grandit pas alors que la charge monte      | `carlysctl autoscale <env>` dit pourquoi : `delai-de-garde`, ou plafond atteint                               |
| `carlysctl` dit « un déploiement est déjà en cours »  | une passe de supervision ou un `deploy.sh` tient le verrou — `fuser -v /srv/carlys/<env>/.lock`               |
| La mise à jour automatique ne part jamais             | `CARLYS_AUTO_UPDATE`, ou en production la maturation pas encore écoulée — `carlysctl update <env>` dit lequel |
| La recette est repartie sur une version PLUS ANCIENNE | `CARLYS_UPDATE_BRANCH` désigne une branche en retard sur le clone — `carlysctl doctor` nomme les deux         |
| Un réglage écrit dans le `.env` reste sans effet      | la clé y est **deux fois** — seule la dernière compte ; `carlysctl doctor` la nomme                           |

### `carlysctl doctor` — et pourquoi il ne tient aucune liste

`doctor` répond à « qu'est-ce qui manque ? » sur trois plans : les outils et le
**démon** Docker (le binaire présent ne dit rien du démon), les amonts Nginx, et
le contenu de chaque `.env`.

Ce dernier point ne compare **pas** à une liste écrite à la main. Une liste de
variables obligatoires périme au premier ajout dans `compose.yml`, sans que rien
ne le signale — c'est la règle du dépôt (« les écarts se comptent, ils ne se
recopient pas ») appliquée à l'orchestrateur. `doctor` pose donc la question à
Docker Compose :

```bash
docker compose --env-file <.env> config -q
```

C'est l'oracle exact : il connaît les `${VAR:?message}`, tolère celles que `dc`
fournit autrement (`COMPOSE_PROJECT_NAME` arrive par `--project-name`), et rend
le message qui nommera la variable au moment du déploiement. Il a en plus la
propriété qui compte pour un diagnostic — **il fonctionne démon Docker arrêté**,
c'est-à-dire au moment où l'on en a le plus besoin.

Cinq verdicts, dans l'ordre où ils sortent. Les quatre derniers sont là parce
que l'oracle ne peut pas les voir : Compose n'interpole que ce que `compose.yml`
nomme, et tout ce qui traverse `env_file` lui est opaque.

| Ce que `doctor` dit                 | Gravité                                 | Ce qu'il faut faire                                                                                                                                                                             |
| ----------------------------------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Compose REFUSE ce .env`            | **bloquant** — la pile ne démarrera pas | ajouter la variable que le message nomme                                                                                                                                                        |
| `Compose accepte … mais PRÉVIENT`   | **bloquant** — valeur tronquée          | un `$` dans une valeur ouvre une substitution : le **doubler** en `$$`                                                                                                                          |
| `<CLÉ> est déclarée PLUSIEURS FOIS` | **bloquant** — panne silencieuse        | supprimer les lignes en trop ; c'est la **dernière** qui gagne                                                                                                                                  |
| `<CLÉ> est déclarée VIDE`           | **bloquant** — l'API ne démarrera pas   | la **commenter**, pas la vider : Zod refuse la chaîne vide même là où il a un défaut. Ne porte que sur les variables du schéma de l'API — `COMPOSE_PROFILES=` est vide **exprès** en production |
| `<CLÉ> porte encore un CHANGE_MOI_` | **bloquant** — valeur factice publique  | `carlysctl env-sync <env> --appliquer --tout`, ou la vraie valeur à la main                                                                                                                     |
| `<CLÉ> absente`                     | **bloquant**                            | `carlysctl env-sync <env> --appliquer` (voir ci-dessous)                                                                                                                                        |

Hors des `.env`, `doctor` réclame aussi, à chaque passage, la **copie hors
machine** des sauvegardes tant que `/srv/carlys/sauvegarde-distante.env` manque
ou reste au modèle — un manque compté dès que la production est déployée, et
une copie distante vieille de plus de deux jours. Voir
[`scripts/server/README.md`](../../scripts/server/README.md), « La copie hors
machine ».

Deux de ces verdicts méritent un mot, parce qu'ils viennent de pannes mesurées
et non d'une précaution de principe.

**`PRÉVIENT` n'est pas un détail.** `docker compose config -q` rend **0** en
prévenant lorsqu'une valeur contient un `$` : `POSTGRES_PASSWORD=mot$de$passe`
arrive dans le conteneur comme `mot`. L'oracle l'avait dit sur sa sortie
d'erreur ; l'avaler parce que le code valait 0 aurait été l'échec silencieux que
le dépôt s'interdit.

**`CHANGE_MOI_` n'est pas une valeur inoffensive.** Les valeurs factices des
exemples sont assez longues pour **passer** la validation Zod — 49 caractères
pour `JWT_ACCESS_SECRET`, minimum exigé 32. Une API qui en hérite **démarre**,
et signe tous ses jetons avec une chaîne publiée dans un dépôt Git. C'est
pourquoi `doctor` n'affiche **jamais** la valeur d'exemple d'une clé factice :
il donne la recette, pas la chaîne.

### La branche suivie doit être celle du clone

C'est arrivé, et ça n'a pris que deux minutes : le **10 septembre 2026 à
12:02:16Z**, une recette est repartie de **14 commits en arrière**, toute
seule.

Deux branches entrent en jeu, et rien ne les rapprochait :

|                                 | D'où ça vient                                                |
| ------------------------------- | ------------------------------------------------------------ |
| les **images** déployées        | `CARLYS_UPDATE_BRANCH`, **`development` par défaut**         |
| les **scripts** et les exemples | la branche sur laquelle le clone `/srv/carlys/repo` est posé |

Le serveur travaillait sur une branche de fonctionnalité que `main` n'avait pas
encore reçue. Or `images-publish.yml` publie les images des **deux** branches :
la tête de `main` avait donc bien ses trois images, tous les contrôles
existants passaient, et rien n'a fait obstacle. Ce qui tournait a été remplacé
par plus ancien, sans un mot.

Deux garde-fous en sont sortis.

**`carlysctl doctor` nomme la divergence** dès que la mise à jour automatique
est active :

```
⚠ mise à jour auto ACTIVE, et les deux branches DIVERGENT :
      images suivies  : main
      scripts du clone : claude/…
  Si « main » est en retard, la pile RECULE.
  Aligner l'une sur l'autre : CARLYS_UPDATE_BRANCH=claude/… dans
    infrastructure/server/config/<env>.conf (un commit, ADR 0017),
    ou retirer la ligne du .env si un ancien réglage l'y masque.
```

**`carlysctl update` refuse un recul.** Le critère est l'**ancêtre**, et il est
choisi précisément : un `git revert` fabrique un commit **neuf**, descendant de
ce qui tourne — il n'est jamais un ancêtre, donc un retour arrière voulu passe
sans entrave. Seul le recul littéral est refusé. En cas de doute — un objet que
le dépôt local ne connaît pas — il refuse aussi : une mise à jour qui attend et
le dit vaut mieux qu'un déploiement à l'aveugle.

Reculer reste possible, mais c'est une **commande**, pas un automatisme :

```bash
carlysctl deploy staging <sha>
```

### Les alertes — ce qui sort de la machine, et ce qui n'en sortira jamais

Le dépôt affirmait, à deux endroits, que le code de retour de la sauvegarde
suffisait à alerter via cron. **C'était faux, pour trois raisons
indépendantes** : cron n'envoie un courriel que si le travail produit de la
**sortie**, or la ligne de cron redirige tout vers `logger` ; il n'y a pas de
`MAILTO` ; et aucun MTA n'est installé. Une sauvegarde qui échouait toutes les
nuits ne réveillait personne.

L'alerte part désormais des scripts eux-mêmes, par `curl` — **déjà** un outil
requis, et il sait parler SMTP. Aucun MTA à installer, aucune dépendance
ajoutée.

| Ce qui déclenche                                                                                             | Où                       |
| ------------------------------------------------------------------------------------------------------------ | ------------------------ |
| sauvegarde d'une base **déployée** échouée                                                                   | `backup.sh`, chaque nuit |
| déploiement automatique échoué, sha mis de côté                                                              | `_update.sh`             |
| **plafond de réparations atteint** — l'orchestrateur a renoncé                                               | `_heal.sh`               |
| disque encore au-delà du seuil APRÈS élagage                                                                 | `_prune.sh`              |
| balayage quotidien des photos de repas orphelines en échec (nouvel essai toutes les heures jusqu'à réussite) | `_photos.sh`             |

**On n'alerte que sur les transitions**, et c'est ce qui rend le système
lisible. La supervision repasse toutes les deux minutes : signaler un _état_
enverrait 720 messages par jour.

```
sain  → panne : on envoie, tout de suite
panne → panne : silence, sauf rappel au bout de CARLYS_ALERT_RAPPEL_HEURES (24 h)
panne → sain  : « RESOLU », avec la durée de la panne
sain  → sain  : rien
```

Mesuré sur un vrai récepteur : **six appels → trois messages** (trois
signalements identiques fondus en un, plus une panne distincte, plus une
résolution issue de deux appels).

Deux canaux, un seul suffit — dans `/srv/carlys/alertes.env` :

```bash
# le plus simple, et ça arrive sur le téléphone — aucun identifiant
CARLYS_ALERT_WEBHOOK=https://ntfy.sh/<un-sujet-long-et-imprevisible>

# ou par courriel, via un relais qui n'est PAS celui de l'application
CARLYS_ALERT_TO=toi@exemple.fr
CARLYS_ALERT_SMTP_URL=smtp://relais:587
```

Le relais de l'application ne convient pas : en recette, `SMTP_HOST` vaut
`mailpit`, un attrapeur **local**. Une alerte qui y atterrirait ne sortirait
jamais de la machine — exactement le défaut qu'on répare.

Éprouver le canal **avant** d'en avoir besoin, parce qu'un système d'alerte
qu'on n'a jamais vu fonctionner est une hypothèse, pas un système :

```bash
carlysctl alert-test
```

`carlysctl doctor` compte l'absence de canal comme un **défaut** et le dit.

> **Ce qu'aucune alerte ne peut faire : prévenir que la machine est morte.**
> Une alerte part _de_ la machine ; si elle ne répond plus, rien ne part, et le
> silence ressemble à « tout va bien ». Couvrir ce cas demande une surveillance
> **extérieure** — un service qui interroge `/health/live` et crie quand il
> n'obtient rien. Elle n'est pas dans ce dépôt, et rien ici ne la remplace.

### `carlysctl env-sync` — le `.env` se complète tout seul

`setup.sh` ne réécrit jamais un `.env` existant : c'est sa propriété la plus
importante, sinon il écraserait les secrets à chaque exécution. La conséquence
est qu'un réglage introduit **après** la création du fichier n'y arrive jamais
seul. Trois variables sont nées ainsi sur le premier serveur en service, et
chacune a demandé une intervention à la main — deux après une panne.

```bash
carlysctl env-sync staging                      # essai : dit ce qu'il ferait
carlysctl env-sync staging --appliquer          # écrit les valeurs recopiables
carlysctl env-sync staging --appliquer --tout   # + engendre les secrets sûrs
```

Quatre classements, et **ils ne sont écrits nulle part à la main** — ils se
lisent dans le fichier d'exemple, qui porte déjà la convention `CHANGE_MOI_` et
une directive `#carlysctl:engendrer` au-dessus des secrets qu'on sait fabriquer
sans casser d'état extérieur :

| Cas                                  | Ce qui se passe                                | Pourquoi                                                                                                             |
| ------------------------------------ | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| valeur en clair dans l'exemple       | **recopiée**                                   | `CARLYS_API_REPLICAS=1`, `SWAGGER_ENABLED=false` : la valeur que le script utilisait déjà comme défaut               |
| secret marqué `#carlysctl:engendrer` | **engendré** avec `--tout`, **jamais affiché** | `METRICS_TOKEN`, `JWT_ACCESS_SECRET` : rien d'extérieur n'en dépend, une valeur neuve ne casse rien                  |
| secret marqué `#carlysctl:engendrer-auto` | **engendré par la supervision elle-même**, jamais affiché | `LOG_FINGERPRINT_SECRET` : son absence a un repli (la clé dérivée du secret JWT), rien d'autre ne le lit |
| tout le reste                        | **refusé**, avec la raison                     | `DOMAIN` casserait le site ; `POSTGRES_PASSWORD` engendré fermerait la base à double tour sur des données existantes |

Le défaut, en l'absence de directive, est de **refuser** : une variable ajoutée
sans qu'on y pense tombe donc du côté prudent.

Quatre garanties, parce qu'un outil qui écrit dans le fichier des secrets doit
les énoncer :

- il **n'écrase jamais** une ligne existante — il n'ajoute que des clés absentes ;
- il écrit **en fin de fichier**, pour qu'une valeur comme
  `https://app-staging.${DOMAIN}` trouve au-dessus d'elle ce qu'elle référence ;
- il **sauvegarde** avant d'écrire (`.env.avant-sync-<horodatage>`, en 600), et
  **restaure** si Compose refuse le fichier après coup ;
- il **n'affiche jamais** un secret engendré : ni sur le terminal, ni dans le
  journal systemd.

La supervision l'appelle à chaque passe, avant tout le reste, mais **sans**
`--tout` : elle recopie, elle n'invente pas — sauf les secrets
`engendrer-auto`. `CARLYS_ENV_SYNC=non` la fait
taire.

> **Ne jamais faire `cat <exemple> >> .env`.** Les clés déjà présentes se
> retrouveraient en double, et c'est la **dernière** qui gagne : un
> `CARLYS_AUTO_UPDATE=oui` posé en haut serait annulé par le `=non` de
> l'exemple recopié en bas, sans le moindre message. `env-sync` fait le travail
> correctement ; `doctor` signale le fichier abîmé si l'on a essayé autrement.

### Le clone du serveur se met à jour aussi

`update_run` déploie des **images** ; il ne touchait pas au dépôt cloné dans
`/srv/carlys/repo`. Les scripts, le `compose.yml` et les fichiers d'exemple
restaient donc figés au dernier `git pull` tapé à la main — et `env-sync`, qui
compare à ces exemples, n'avait rien de neuf à comparer.

La supervision termine désormais sa passe en avançant le clone (`git fetch`,
puis avance rapide seulement), **sous la même autorisation que le
déploiement** (`CARLYS_AUTO_UPDATE`, puisque « suivre la branche » inclut les
scripts). Un clone qui porte des modifications locales ou qui a divergé est
**signalé, jamais écrasé**.

Le clone n'avance **que jusqu'à un commit qui a passé la porte de CI** : la
tête de la branche n'est prise que si son image API existe, donc si `api-ci`,
`admin-ci`, `images-ci` et `infra-ci` étaient verts pour son code. Sinon (CI
rouge, ou encore en cours), il reste où il est et réessaie à la passe
suivante. C'est ce clone, partagé par la recette et la production, qui fournit
`backup.sh`, `deploy.sh`, la réparation et le `compose.yml` : un `git pull` de
la tête y amenait un script serveur qu'`infra-ci` venait de rejeter, exécuté
la nuit même sur la production.

Remplacer un script pendant qu'il s'exécute est sans danger, et c'est mesuré :
`git checkout` crée un nouveau fichier et le renomme par-dessus, l'inode change,
et le `bash` en cours garde son descripteur sur l'ancien. La passe en cours
finit sur les anciens scripts ; la suivante prend les nouveaux.

---

## 11. Migrer un serveur DÉJÀ en service

À lire si ta recette tournait **avant** l'orchestrateur — typiquement si tu
t'es arrêté à l'étape 7 du guide de mise en route. Quatre choses ont bougé
sous elle :

1. **l'admin change de port** — 3101 → 3150 en recette, 3001 → 3050 en
   production. Il fallait laisser la place à la plage de l'API ;
2. **l'API réserve une plage** au lieu d'un port, et son `.env` réclame deux
   lignes qu'il n'avait pas ;
3. **les vhosts ne déclarent plus l'amont de l'API** — il est engendré dans
   `/etc/nginx/conf.d/` ;
4. **une minuterie systemd s'installe**, et se met à passer toutes les deux
   minutes.

### L'ordre n'est pas indifférent

Tant que l'ancien vhost déclare `upstream carlys_api_staging` **et** que
`setup.sh` en pose un dans `conf.d/`, Nginx refuse **toute** la configuration —
pas seulement le doublon :

```
[emerg] duplicate upstream "carlys_api_staging"
        in /etc/nginx/sites-enabled/carlys-staging.conf:1
nginx: configuration file /etc/nginx/nginx.conf test failed
```

Mesuré. Le vhost doit donc être remplacé **avant** que `setup.sh` ne soit
rejoué, jamais après.

### La séquence

```bash
# 1. Le clone du serveur, d'abord. Tout le reste en dépend.
sudo git -C /srv/carlys/repo pull --ff-only
cd /srv/carlys/repo

# 2. Le .env de la recette : deux lignes à ajouter, une à corriger.
#    (Migration de septembre 2026, AVANT l'ADR 0017 : depuis, ces réglages
#    vivent dans infrastructure/server/config/, et `carlysctl config-migrer`
#    vide le .env de ceux qui y traîneraient encore.)
sudo nano /srv/carlys/staging/.env
#    CARLYS_API_HOST_PORT=3100          (inchangé)
#  + CARLYS_API_HOST_PORT_LAST=3119     ← NOUVEAU, obligatoire
#  ~ CARLYS_ADMIN_HOST_PORT=3150        ← était 3101
#  + CARLYS_API_REPLICAS=1              ← NOUVEAU
#    Les réglages CARLYS_SCALE_*, CARLYS_HEAL_* et CARLYS_AUTO_UPDATE ont tous
#    un défaut : rien à écrire tant qu'on ne veut pas les changer.
#    Ne PAS recopier l'exemple en bloc : les clés en double s'annulent en
#    silence (voir § 10). Pour savoir ce qui manque vraiment :
#      sudo ./scripts/server/carlysctl doctor

# 3. Le vhost, AVANT setup.sh (voir ci-dessus).
DOMAINE=carlys.example        # ← ton domaine réel
sed "s/carlys\.example/$DOMAINE/g" infrastructure/nginx/carlys-staging.conf.example \
  | sudo tee /etc/nginx/sites-available/carlys-staging.conf > /dev/null
sudo ln -sf /etc/nginx/sites-available/carlys-staging.conf /etc/nginx/sites-enabled/
# Les snippets aussi, TOUS : carlys-proxy.conf a changé (`proxy_set_header
# Connection ""`, sans quoi le pool de connexions de l'amont existerait sans
# jamais servir), et les vhosts `api` incluent carlys-compression-api.conf —
# absent, `nginx -t` refuse. Le format de journal sans jeton
# (conf.d/carlys-journal.conf), lui, est posé par setup.sh à l'étape 4.
sudo cp infrastructure/nginx/snippets/*.conf /etc/nginx/snippets/

# 4. setup.sh : il pose les amonts de départ et la minuterie. Il NE TOUCHE PAS
#    aux .env déjà remplis — c'est sa propriété la plus importante.
sudo CARLYS_PROXY_CIDR=<adresse de gra6> ./scripts/server/setup.sh

# 5. Nginx doit accepter la configuration MAINTENANT.
sudo nginx -t

# 6. Déployer le sha qui porte l'orchestrateur. C'est ce déploiement qui
#    recrée les conteneurs sur les nouveaux ports et qui réécrit l'amont.
sudo ./scripts/server/carlysctl deploy staging <sha12>

# 7. Regarder.
sudo ./scripts/server/carlysctl status staging
```

### Ce qui est indisponible, et combien de temps

Entre l'étape 3 et l'étape 6, le vhost pointe l'admin sur 3150 alors que le
conteneur publie encore 3101 : **`app-staging` rend 502** pendant cet
intervalle. C'est de la recette, et la fenêtre est celle d'un déploiement —
quelques minutes. L'API, elle, ne bouge pas : l'amont de départ posé par
`setup.sh` vise 3100, exactement là où l'ancien conteneur écoute encore.

Déplacer le déploiement avant le vhost ne supprime pas la fenêtre, elle la
déplace et l'aggrave : le nouveau `compose.yml` publierait l'admin sur 3150 —
que l'ancien vhost cherche encore sur 3101 — **et** l'API sur un port de la
plage que Docker choisit librement, pas nécessairement 3100. Les deux hôtes
tomberaient au lieu d'un seul. Il n'y a pas d'ordre sans couture : autant
prendre la version courte et annoncée.

### Les DEUX vhosts, pas seulement celui de la recette

Le guide de mise en route installe les vhosts des **deux** environnements
(sa boucle `for env in staging production`), même quand la production n'est pas
encore montée. Si tu ne remplaces que celui de la recette, `setup.sh` posera
l'amont de départ de la production à côté d'un vhost qui le déclare encore —
et Nginx refusera toute la configuration pour ce doublon-là. Remplace les deux
en une fois :

```bash
for env in staging production; do
  sed "s/carlys\.example/$DOMAINE/g" "infrastructure/nginx/carlys-$env.conf.example" \
    | sudo tee "/etc/nginx/sites-available/carlys-$env.conf" > /dev/null
  sudo ln -sf "/etc/nginx/sites-available/carlys-$env.conf" /etc/nginx/sites-enabled/
done
```

### Si tu as déployé AVANT de remplacer le vhost

C'est le cas le plus probable, et il se rattrape sans rien casser. Le
déploiement a réussi, mais `carlysctl` n'a pas pu poser l'amont : il te l'a dit,
avec le refus de Nginx recopié et sa cause nommée. Remplace les vhosts
ci-dessus, puis :

```bash
sudo ./scripts/server/carlysctl heal staging
```

`heal` réconcilie l'amont même sur une pile parfaitement saine — c'est
précisément la panne qu'aucun contrôle de conteneur ne montre.

Entre le déploiement et ce rattrapage, `app-staging` rend 502 : le vhost
cherche l'admin sur son ancien port. L'API, elle, continue de répondre tant que
Docker lui a laissé le premier port de la plage.

### Vérifier que la migration a pris

```bash
carlysctl status staging
```

Quatre lignes à lire, dans cet ordre :

- `exemplaires API   1 en vie / 1 voulus (plafond …, plage de 20)` — la plage
  est reconnue ;
- `ports réels` et `ports servis par nginx` portent **la même valeur** ; s'il y
  a un `⚠ ÉCART`, `carlysctl heal staging` ;
- `utilisateurs en ligne` affiche un nombre (même 0) et non « inconnu » — la
  présence Redis fonctionne, donc la mise à l'échelle a de quoi décider ;
- `réparations (1 h)  0 / 5`.

Puis la minuterie :

```bash
systemctl list-timers carlys-supervision.timer
journalctl -u carlys-supervision.service -n 40
```

### Et la production ?

Rien à faire tant que tu ne l'as pas montée : `setup.sh` a déposé un
`/srv/carlys/production/.env` d'exemple, et la version du dépôt porte déjà les
bons ports. Tu la traiteras à l'étape 9 du guide, sans migration.

---

## À lire à côté

- [mise-en-route-serveur.md](mise-en-route-serveur.md) — installer le serveur
- [../../infrastructure/deployment/README.md](../../infrastructure/deployment/README.md) — la stratégie de déploiement
- [../../infrastructure/nginx/README.md](../../infrastructure/nginx/README.md) — les vhosts
- [../security/reverse-proxy.md](../security/reverse-proxy.md) — la chaîne de proxys et l'adresse du client
