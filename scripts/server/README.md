# Scripts d'exploitation du serveur dédié

Une machine Debian/Ubuntu, deux environnements (`staging` et `production`)
isolés par projet Compose et par volumes. Ces scripts ne remplacent pas la
stratégie de déploiement — elle est écrite dans
[`infrastructure/deployment/README.md`](../../infrastructure/deployment/README.md)
— ils l'exécutent.

**Un seul point d'entrée : `carlysctl`.** Il route vers les quatre scripts
historiques sans rien leur recopier, et ajoute ce qu'aucun ne portait — l'état
des lieux, la mise à l'échelle, la réparation, la mise à jour autonome. C'est
lui que la minuterie systemd appelle toutes les deux minutes.
Tout est décrit dans
[`docs/deployment/orchestration.md`](../../docs/deployment/orchestration.md).

| Commande | Quand | Ce qu'elle fait |
| --- | --- | --- |
| `carlysctl status [env]` | quand on se demande si ça va | version déployée, conteneurs, exemplaires, ports servis par Nginx, utilisateurs en ligne, débit, latence, et ce que le superviseur s'apprête à faire |
| `carlysctl doctor` | après une installation, ou quand rien ne marche | nomme ce qui manque sur la machine |
| `carlysctl scale <env> <n>` | à la main | fixe le nombre d'exemplaires d'API |
| `carlysctl autoscale <env>` | pour comprendre une décision | dit ce qu'il ferait ; n'agit qu'avec `--appliquer` |
| `carlysctl heal <env>` | quand quelque chose est tombé | relève ce qui manque, avec un plafond horaire |
| `carlysctl update <env>` | si `CARLYS_AUTO_UPDATE=oui` | recette : suit une branche ; production : promeut la recette après maturation |
| `carlysctl supervise [env]` | par la minuterie | une passe complète : réparer, mettre à l'échelle, mettre à jour |
| `carlysctl deploy \| promote \| backup` | — | route vers les scripts ci-dessous, sans rien y ajouter |

| Script | Quand | Ce qu'il fait |
| --- | --- | --- |
| `setup.sh` | une fois, puis à chaque fois qu'une brique est ajoutée | prépare la machine : docker + plugin compose, nginx, ufw (22, et 80 **depuis le seul reverse proxy**), amonts Nginx de départ, `/srv/carlys`, copie des `.env` d'exemple, cron de sauvegarde, minuterie de supervision. **Idempotent.** |
| `deploy.sh` | à chaque livraison en recette | `deploy.sh <staging\|production> <sha>` : pull des trois images, migration, bascule, santé de **chaque** exemplaire, retour arrière si besoin |
| `promote.sh` | pour une mise en production | rejoue en production **le sha déjà validé en recette**, après vérification du registre et confirmation humaine |
| `backup.sh` | tous les jours, par cron | `pg_dump` de chaque base **déployée**, horodaté, rétention 14 jours |

## Les bibliothèques

Aucune ne s'exécute seule ; toutes sont chargées par `_common.sh`, et aucune ne
fait d'effet de bord au chargement.

| Fichier | Ce qu'il sait |
| --- | --- |
| `_common.sh` | chemins, verrou d'environnement, lecture du journal `DEPLOYED`, appel de Compose, attente HTTP bornée |
| `_replicas.sh` | exemplaires de l'API, leurs ports réels, l'amont Nginx engendré |
| `_state.sh` | la mémoire entre deux passages de supervision |
| `_metrics.sh` | lecture de `/metrics` sur chaque exemplaire, et dérivation d'un débit |
| `_scale.sh` | la décision de mise à l'échelle, et ses garde-fous |
| `_heal.sh` | la réparation, et son plafond horaire |
| `_update.sh` | la mise à jour autonome, et ce qui l'autorise |
| `_status.sh` | l'état des lieux |

Elles existent pour que chaque règle ne soit écrite qu'une fois — `promote.sh`
lit le `DEPLOYED` que `deploy.sh` écrit, `backup.sh` s'en sert pour savoir si
un environnement a déjà hébergé quelque chose, et `carlysctl` ne réinvente
aucun des deux.

## Ce qu'ils supposent

- le dépôt cloné sur le serveur (ils lisent `infrastructure/server/compose.yml`
  et `infrastructure/server/env/*.env.example`) ;
- l'arborescence du contrat de conception :

```
/srv/carlys/
  staging/.env        production/.env        # secrets, mode 600
  staging/DEPLOYED    production/DEPLOYED    # journal tenu par deploy.sh
  staging/.lock       production/.lock       # verrou flock d'un déploiement
  staging/orchestrateur.etat                 # mémoire du superviseur, mode 600
  backups/                                   # dumps, mode 700
  ghcr.token                                 # PAT read:packages, mode 600
```

- et, hors de cette arborescence, les amonts Nginx engendrés :

```
/etc/nginx/conf.d/carlys-staging-api-upstream.conf
/etc/nginx/conf.d/carlys-production-api-upstream.conf
```

  Ils sont **écrits par `carlysctl`**, jamais à la main : l'API tourne en
  plusieurs exemplaires sur des ports que Docker attribue dans une plage, et
  une liste écrite à la main serait fausse dès la première mise à l'échelle.

- les images publiées sous `ghcr.io/mimiflo/` et taguées `sha-<12 caractères>` ;
  l'admin de **production** porte en plus le suffixe `-prod` (garde légale
  armée), et c'est la seule différence entre les deux environnements.

## Le TLS n'est pas sur cette machine

Un reverse proxy réseau — `gra6.luuc.fr` — termine le TLS des six noms
publics et relaie **en HTTP clair** vers le port 80 de ce serveur. Les six
domaines pointent en DNS sur lui, par des CNAME ; rien de public ne frappe
directement cette machine. Conséquences pour ces scripts :

- `setup.sh` **n'installe pas certbot** et n'ouvre pas le 443 — il retire même
  une règle 443 laissée par un passage antérieur. Les certificats, leur
  renouvellement et la redirection HTTP → HTTPS vivent sur le proxy ;
- les vhosts d'`infrastructure/nginx/` n'écoutent **qu'en HTTP sur 80** ;
- les URL publiques restent en `https://` (`PUBLIC_APP_URL`, `CORS_ORIGINS`,
  `S3_PUBLIC_BASE_URL`) : le nginx d'ici pose `X-Forwarded-Proto https` **en
  dur**, il ne relaie ni `$scheme` (qui vaudrait `http`) ni un en-tête reçu.

**Le port 80 n'est donc pas un port public**, et `setup.sh` refuse de faire
semblant du contraire : il ouvre 80 depuis la seule adresse donnée par
`CARLYS_PROXY_CIDR`. Sans cette variable, il **n'ouvre pas** le port et le dit
— à l'étape 3 puis dans le récapitulatif final. C'est ce pare-feu qui rend
honnête le `X-Forwarded-Proto https` posé en dur : l'API en déduit
`req.secure=true` alors que la liaison interne est en clair, ce qui n'est vrai
que si le seul émetteur possible est un proxy ayant réellement terminé du TLS.

**Trois en-têtes sont exigés du proxy réseau**, et le récapitulatif de
`setup.sh` les rappelle mot pour mot parce qu'on ne suppose pas qu'ils sont
posés :

```nginx
proxy_set_header Host              $host;          # nom public conservé
proxy_set_header X-Forwarded-For   $remote_addr;   # ÉCRASER, jamais ajouter
proxy_set_header X-Forwarded-Proto https;
```

`$remote_addr` et non `$proxy_add_x_forwarded_for` : mesuré sur la chaîne
montée pour de vrai (client → proxy réseau → nginx d'ici → Express), un client
qui envoie lui-même `X-Forwarded-For: 1.2.3.4` fait retenir `1.2.3.4` à l'API
dès que le proxy **ajoute** au lieu d'écraser — limitation de débit
contournée, audit empoisonné. Un compteur de
sauts ne retire des entrées que par la droite : ce que le client préfixe
survit. Le nginx d'ici, lui, garde `$proxy_add_x_forwarded_for` et ajoute
l'adresse du proxy réseau : c'est le second saut, d'où `TRUST_PROXY_HOPS=2`
dans les deux `.env` (avec `1`, l'API voit l'adresse du proxy et toute la
plateforme partage un seul seau de limitation).

## Le déploiement, dans l'ordre

```bash
scripts/server/deploy.sh staging 4f2a91c0be77
```

0. **verrou de l'environnement** — `flock -n` sur `/srv/carlys/<env>/.lock`.
   Un second déploiement du même environnement est refusé immédiatement, avant
   même la connexion au registre : deux `compose up` concurrents s'entrelacent,
   et surtout écrivent tous deux dans `DEPLOYED`, dont la dernière ligne cesse
   alors de décrire ce qui tourne. Le verrou est **par environnement** — une
   mise en production n'attend pas un déploiement de recette ;
1. connexion au registre, **pull des trois images** — un sha inexistant échoue
   ici, pendant que l'ancienne version sert encore ;
2. `postgres` et `redis` debout (ce n'est pas une bascule : rien de nouveau
   n'est exposé) ;
3. **migration** en tâche ponctuelle, jamais au démarrage du conteneur ;
   **échec ⇒ arrêt, rien n'a été basculé** ;
4. `compose up -d` ;
5. attente **bornée** de `/health/ready` puis de l'admin ;
6. santé absente ⇒ retour au sha précédent lu dans `DEPLOYED` ;
   santé obtenue ⇒ nouvelle ligne dans `DEPLOYED`.

Le retour arrière applique **la même règle de santé que la montée : l'API *et*
l'admin**. N'en contrôler qu'une permettrait de déclarer un environnement
« restauré » avec l'admin en panne, donc les pages publiques avec elle
(vérification d'adresse, réinitialisation de mot de passe, mentions légales).
Si le sha de repli ne rend pas la main non plus, `DEPLOYED` **n'est pas
écrit** : le journal continue de désigner le dernier état sain connu plutôt
que d'affirmer une restauration qui n'a pas eu lieu.

Le retour arrière restaure **le code, pas le schéma** : Prisma n'a pas de
migration descendante. Toute migration doit donc rester compatible avec la
version précédente du code — ajouter une colonne nullable dans un déploiement,
cesser de l'utiliser dans le suivant, la supprimer dans un troisième.

**Premier déploiement.** `DEPLOYED` est vide : il n'y a pas de sha où revenir.
Le script le dit, laisse la pile debout pour le diagnostic, **n'écrit pas**
`DEPLOYED` et sort en erreur. Un journal qui affirmerait qu'un sha malade est
déployé serait pire que pas de journal — `promote.sh` le lit.

## `DEPLOYED`

Journal en ajout seul, **la dernière ligne non commentée désigne ce qui
tourne** — y compris après un retour arrière, qui réinscrit le sha restauré :

```
aaaaaaaaaaaa  2026-09-08T08:28:25Z  flo@carlys-1  deploy
aaaaaaaaaaaa  2026-09-08T08:29:40Z  flo@carlys-1  retour-arrière-depuis-bbbbbbbbbbbb
```

## La promotion est un geste humain

```bash
scripts/server/promote.sh          # le sha courant de staging
```

`promote.sh` vérifie que `carlys-admin:sha-<sha>-prod` existe dans le registre
et demande de **recopier le sha** pour confirmer. Si l'image `-prod` manque
alors que celle de recette existe, ce n'est pas une panne : c'est la garde
légale. Le build de production échoue tant que `docs/legal/*.md` portent des
marqueurs `[À COMPLÉTER : …]`. Le message le dit et donne la marche à suivre.

## Sauvegardes

`backup.sh` exécute `pg_dump --format=custom` **dans le conteneur** postgres :
les bases ne publient aucun port sur l'hôte, et le `pg_dump` de l'image a par
construction la version du serveur (un `pg_dump` 16 refuse un serveur 17). Le
mot de passe n'est **jamais** passé en argument : il est lu dans le conteneur,
depuis le `POSTGRES_PASSWORD` que le compose y place déjà. Un
`--env PGPASSWORD=…` l'écrirait dans `/proc/<pid>/cmdline`, lisible par tout
utilisateur local pendant la durée du dump.

Le fichier est écrit en `.part` puis renommé après vérification de la signature
`PGDMP` — une sauvegarde interrompue ne laisse jamais un fichier d'apparence
normale. La purge ne touche que nos propres fichiers : `staging-*.dump` et
`production-*.dump` de plus de 14 jours, et les fragments `*.dump.part*` de
plus d'un jour (ceux qu'une interruption brutale a laissés ; sans cette
seconde passe ils s'accumuleraient indéfiniment, chacun de la taille d'une
base). Ce qu'un opérateur a déposé là ne disparaît pas.

**Le code de retour EST l'alerte.** La ligne de cron posée par `setup.sh`
tourne sous `bash -o pipefail` : sans lui, le tube `backup.sh | logger`
rendrait le code de `logger`, toujours nul, et cron n'enverrait jamais rien.
Elle ne vaut donc que si elle ne crie pas pour rien : un environnement dont le
`DEPLOYED` est vide n'a **jamais rien hébergé** — `setup.sh` crée pourtant les
deux `.env` dès le premier jour — il est sauté sans compter d'échec. Un
environnement **déployé** dont postgres ne tourne pas, lui, a des données qui
ne sont pas sauvegardées : celui-là fait sortir en erreur.

Restaurer (à faire régulièrement — une sauvegarde jamais restaurée n'en est
pas une) :

```bash
docker compose -p carlys_staging --env-file /srv/carlys/staging/.env \
  -f infrastructure/server/compose.yml exec -T postgres \
  pg_restore -U carlys -d carlys_staging --clean --if-exists \
  < /srv/carlys/backups/staging-20260908T030000Z.dump
```

## Variables

Aucune n'est nécessaire sur un serveur normal ; elles existent pour pouvoir
jouer ces scripts hors serveur, contre une arborescence jetable.

| Variable | Défaut | Rôle |
| --- | --- | --- |
| `CARLYS_ROOT` | `/srv/carlys` | racine des données |
| `CARLYS_COMPOSE_FILE` | `infrastructure/server/compose.yml` | fichier compose |
| `CARLYS_REGISTRY` | `ghcr.io/mimiflo` | préfixe complet des images ; le `.env` de l'environnement fait foi |
| `CARLYS_HEALTH_TRIES` / `CARLYS_HEALTH_DELAY` | `60` / `2` | attente de santé (bornée) |
| `CARLYS_BACKUP_RETENTION_DAYS` | `14` | rétention des dumps |
| `CARLYS_SETUP_DRY_RUN` | — | `1` : `setup.sh` affiche les commandes système au lieu de les jouer |
| `CARLYS_PROXY_CIDR` | **aucun** | adresse ou réseau du reverse proxy réseau, seule source autorisée sur le port 80 |

`CARLYS_PROXY_CIDR` est la seule qui compte sur un vrai serveur. **Pas de
défaut** : un défaut inventé ouvrirait un port à des machines qu'on n'a pas
choisies tout en donnant l'apparence d'une règle réfléchie. Vide, `setup.sh`
n'ouvre pas le 80 — une machine injoignable se répare en une commande, un
`req.secure=true` mensonger ne se voit pas.

```bash
CARLYS_PROXY_CIDR=<adresse du proxy> sudo scripts/server/setup.sh
```

`deploy.sh` **exporte** vers Compose quatre variables, et l'environnement du
shell l'emportant sur `--env-file`, un déploiement ne réécrit jamais le `.env` :

| Exportée | Valeur |
| --- | --- |
| `CARLYS_TAG` | `sha-<sha>` |
| `CARLYS_ADMIN_TAG_SUFFIX` | `-prod` en production, vide en recette |
| `CARLYS_ENV_FILE` | le chemin absolu du `.env` réellement ouvert |
| `CARLYS_REGISTRY` | relu dans ce `.env` |

Le suffixe `-prod` est **déduit de l'environnement visé**, pas lu dans le
`.env` : un `.env` de production dont le suffixe aurait été effacé déploierait
sinon l'image de recette, garde légale désarmée, sans que rien ne proteste.

La migration passe par le service `migrate` du compose (profil dédié, donc
absent de tout `up -d`), appelé en `run --rm` : réseau, `DATABASE_URL` et
fichier d'environnement y sont déjà décrits, et une seconde description
finirait par diverger de la première. **Sans `--no-deps`** : le
`depends_on: postgres, condition: service_healthy` du compose est la seule
description de « la base est prête », et c'est elle qui fait foi — la couper
ferait reposer la migration sur un second avis, plus faible, qui divergerait
du compose au premier changement.

## Ce qu'ils n'automatisent pas

DNS (six CNAME vers `gra6.luuc.fr`), achat du domaine, **configuration du
reverse proxy réseau** — il n'est pas sur cette machine : certificats des six
noms, terminaison TLS, routage vers le port 80 d'ici et les trois
`proxy_set_header` ci-dessus —, ouverture du 80 quand `CARLYS_PROXY_CIDR` n'a
pas été donnée, vraies valeurs des secrets, remplissage des marqueurs légaux,
comptes des magasins d'applications. `setup.sh` termine en les listant, avec
pour chacun la commande exacte.

Plus de certbot dans cette liste, et plus nulle part ailleurs : ce serveur ne
génère, ne détient et ne renouvelle aucun certificat.
