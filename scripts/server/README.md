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
| `carlysctl doctor` | après une installation, après un `git pull`, ou quand rien ne marche | nomme ce qui manque : outils, démon Docker, amonts Nginx, la copie hors machine des sauvegardes, et — en le demandant à Compose lui-même — ce qui manque ou se contredit dans chaque `.env` |
| `carlysctl scale <env> <n>` | à la main | fixe le nombre d'exemplaires d'API |
| `carlysctl autoscale <env>` | pour comprendre une décision | dit ce qu'il ferait ; n'agit qu'avec `--appliquer` |
| `carlysctl heal <env>` | quand quelque chose est tombé | relève ce qui manque, avec un plafond horaire |
| `carlysctl admin-create <env> <email> [--role …] [--reset-password]` | après le premier déploiement, puis pour chaque collègue | crée un compte du back-office par la commande embarquée dans l'image API — la seule voie qui existe. Mot de passe saisi sans écho, jamais en argument. **`--role` ne touche aux rôles que s'il est écrit** : à la création il vaut `superadmin` par défaut, mais sur un compte existant (`--reset-password`) l'omettre laisse ses rôles INTACTS, et le préciser les REMPLACE |
| `carlysctl coach-bench <env> [--levels 1,5,10,25,50,100] [--question …] [--confirm]` | avant d'ouvrir le coach à du monde, puis après chaque changement de machine ou de réglages | le banc de charge du coach (ADR 0013) : des questions réelles, palier par palier, par le chemin du téléphone. Rend réussies, « très sollicité », délais dépassés, réponses par minute, délai du premier mot et de la réponse, file la plus longue. Ses comptes de banc sont supprimés à la fin, Ctrl-C compris ; 100 personnes au plus par palier. Il **occupe le coach** pendant la mesure : `--confirm` exigé sur la production |
| `carlysctl catalog-seed <env> [--sans-photos]` | **rarement** : le déploiement le fait déjà (étape 5/8). Pour recharger sans redéployer — après un `CARLYS_DEPLOY_CATALOG=non`, ou après avoir réparé le stockage, **une fois la bascule réussie** | charge groupes musculaires, matériels, exercices et photos (MinIO) — idempotent par slug, purge le cache Redis du catalogue, puis efface du stockage les versions précédentes des photos changées. Même code que l'étape du déploiement. Charge le catalogue de la version **déployée** : après un déploiement interrompu, c'est celui du sha précédent — redéployer, plutôt |
| `carlysctl subscription-catalog <env>` | **rarement** : le déploiement le fait déjà (étape 6/8). Après avoir changé un `STRIPE_PRICE_*` ou un `REVENUECAT_PRODUCT_*` du `.env`, sans redéployer | projette plans, droits et produits de paiement — idempotent. Un identifiant remplacé reste lié : ses abonnés renouvellent dessus. Sort en 1 si un fournisseur configuré (clé ou secret de webhook Stripe, secret de webhook RevenueCat), ou qui a encore des abonnés qui prélèvent, manque de son secret de webhook ou de tout produit : un paiement serait encaissé sans rien accorder. Sans aucun moyen de paiement ni abonné, sort en 0 avec un AVERTISSEMENT : Premium ne s'obtient alors que par le back-office |
| `carlysctl meal-photos-sweep <env> [--a-blanc]` | **rarement** : la supervision le fait une fois par jour. Pour compter sans effacer, ou rejouer tout de suite un balayage raté une fois le stockage réparé | efface du bucket PRIVÉ les photos de repas que plus aucune ligne d'un repas (et d'un compte) vivant ne cite ; épargne les objets de moins d'une heure ; sort en erreur si un effacement échoue |
| `carlysctl deleted-accounts-purge <env> [--a-blanc] [--compte <uuid>] [--compte-actif <uuid>]` | **rarement** : la supervision le fait une fois par jour (`_purge_comptes.sh`). Pour compter sans effacer, rejouer une purge ratée, ou exécuter une demande d'effacement IMMÉDIAT (`--compte-actif` pour un compte encore actif, `--compte` pour un compte déjà supprimé ; l'UUID se relève AVANT la suppression, qui efface tout ce qui y mène, et RIEN ne part avant que la personne ait renvoyé le code écrit à l'adresse du compte, l'expéditeur d'un courriel se falsifiant : procédure dans `docs/deployment/orchestration.md`, « Effacement immédiat sur demande ») | efface définitivement les comptes supprimés depuis plus de `CARLYS_ACCOUNT_PURGE_DAYS` jours (30 par défaut) : leurs photos privées, puis leur ligne et, par cascade, tout ce qui s'y rattache (le journal d'audit reste, sans le lien). `--compte` refuse un compte qui n'est pas déjà supprimé. `--compte-actif` le supprime d'abord comme l'appli (Stripe résilié, audit), puis l'efface ; l'adresse du compte se tape au clavier, jamais en argument (l'historique du shell la garderait), et doit être la sienne. Sort en 1 si un compte n'a pas pu être effacé, en 2 sur un refus |
| `carlysctl env-sync <env> [--appliquer] [--tout]` | après un `git pull`, ou quand `doctor` signale une clé absente | ajoute au `.env` les réglages introduits depuis sa création. N'écrase jamais une ligne, engendre les secrets sûrs avec `--tout`, refuse ce qu'un humain seul peut choisir |
| `carlysctl update <env>` | si `CARLYS_AUTO_UPDATE=oui` | recette : suit une branche ; production : promeut la recette après maturation |
| `carlysctl supervise [env]` | par la minuterie | une passe complète : réparer, mettre à l'échelle, élaguer, balayer les photos de repas orphelines et purger les comptes supprimés (une fois par jour chacun), mettre à jour |
| `carlysctl deploy \| promote \| backup` | — | route vers les scripts ci-dessous, sans rien y ajouter |

| Script | Quand | Ce qu'il fait |
| --- | --- | --- |
| `setup.sh` | une fois, puis à chaque fois qu'une brique est ajoutée | prépare la machine : docker + plugin compose, nginx, ufw (22, et 80 **depuis le seul reverse proxy**), amonts Nginx de départ, `/srv/carlys`, copie des `.env` d'exemple, cron de sauvegarde, minuterie de supervision. **Idempotent.** |
| `deploy.sh` | à chaque livraison en recette | `deploy.sh <staging\|production> <sha>` : pull des trois images, migration, bascule, santé de **chaque** exemplaire, retour arrière si besoin |
| `promote.sh` | pour une mise en production | rejoue en production **le sha déjà validé en recette**, après vérification du registre et confirmation humaine |
| `backup.sh` | tous les jours, par cron | `pg_dump` de chaque base **déployée** + miroir `mc` du bucket MinIO figé par instantanés à liens durs, rétention 14 jours, puis **copie chiffrée hors machine** si une cible S3 est posée, alerte en cas d'échec |

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
| `_envcheck.sh` | ce que Compose pense d'un `.env`, et les quatre pièges qu'il ne voit pas |
| `_envsync.sh` | compléter un `.env` sans jamais rien deviner |
| `_repo.sh` | le clone du serveur — qui n'avance que jusqu'à un commit dont les images existent — et la divergence de branches |
| `_alert.sh` | faire SORTIR une alerte, et ne la crier qu'une fois |
| `_sauvegarde.sh` | le dump d'une base (sauvegarde nocturne ET avant chaque migration de production) |
| `_hors_site.sh` | la copie chiffrée des sauvegardes vers un stockage S3 distant, et l'avertissement de `doctor` tant qu'elle manque |
| `_quotidien.sh` | la mécanique des tâches quotidiennes : une fois par jour, un nouvel essai dans l'heure après un échec, une alerte tant qu'il dure |
| `_photos.sh` | le balayage quotidien des photos de repas orphelines |
| `_purge_comptes.sh` | la purge quotidienne des comptes supprimés, et le délai du `.env` |

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
  sauvegarde-distante.env                    # cible S3 hors machine, mode 600 (facultatif)
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
  armée), et c'est la seule différence entre les deux environnements. MinIO et
  `mc` (`carlys-minio`, `carlys-mc`), construits depuis leurs sources, sont
  dans le même registre mais étiquetés par recette, pas par sha
  (`infrastructure/minio/README.md`).

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
   ici, pendant que l'ancienne version sert encore — puis des deux images de
   MinIO que référence `compose.yml` (même raison) ;
2. `postgres` et `redis` debout (ce n'est pas une bascule : rien de nouveau
   n'est exposé) ;
3. **en production, dump de la base** (`backups/avant-migration-…`) puis
   **migration** en tâche ponctuelle, jamais au démarrage du conteneur ;
   **échec de l'un ou de l'autre ⇒ arrêt, rien n'a été basculé** ;
4. **catalogue d'exercices**, puis **catalogue d'abonnement**, toujours avant
   la bascule. Le second n'arrête le déploiement que si un paiement pourrait
   être encaissé sans rien accorder (fournisseur sans secret de webhook ou
   sans produit) ; sans aucun moyen de paiement (la recette), il avertit que
   Premium ne s'obtient que par le back-office, et le déploiement continue ;
5. `compose up -d` ;
6. attente **bornée** de `/health/ready` puis de l'admin ;
7. santé absente ⇒ retour au sha précédent lu dans `DEPLOYED` ;
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

**Le filet des DONNÉES, lui, est le dump d'avant-migration.** En production,
`deploy.sh` sauvegarde la base juste avant `migrate deploy`
(`backups/avant-migration-production-<horodatage>-<sha>.dump`) et s'arrête si
ce dump échoue. Avant, la seule copie était celle de la nuit : une migration
destructrice passée l'après-midi emportait jusqu'à une journée d'écritures.
Les **trois** derniers sont gardés (`CARLYS_BACKUP_PREMIGRATION_KEEP`),
**30 jours au plus** (`CARLYS_BACKUP_PREMIGRATION_MAX_DAYS`) : plus que les
14 jours des dumps de la nuit, parce qu'une corruption silencieuse peut se
découvrir des semaines plus tard et que c'est alors la seule base propre ;
mais bornés quand même, parce qu'ils contiennent aussi les comptes supprimés
depuis, que la purge quotidienne efface de la base. La borne d'âge
s'applique chaque nuit (`backup.sh`), pas seulement au déploiement suivant :
un trimestre sans déploiement ne laisse plus de dumps de huit mois. En
recette, rien par défaut (`CARLYS_DEPLOY_BACKUP=oui` l'arme). Restaurer se fait
comme ci-dessous, avec ce fichier-là.

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

**Les médias aussi, et l'histoire est gardée par liens durs.** `mc mirror`
recopie le bucket en fichiers ordinaires dans `backups/minio-<env>/courant`
(l'API S3, jamais le format interne de MinIO), puis chaque nuit réussie est
figée par `cp -al` en `instantane-<horodatage>` : quatorze nuits coûtent une
seule taille de bucket plus les fichiers qui ont changé, et un objet supprimé
du bucket reste vivant dans les instantanés antérieurs — mesuré, contenu
intact. Restaurer un objet : le recopier depuis l'instantané voulu (`mc cp`,
ou `mc mirror --overwrite /chemin/instantane-X local/<bucket>` pour tout
remettre). La rétention des instantanés obéit à la même règle que les dumps :
on ne jette que si l'on vient de figer un neuf.

**L'alerte part de `backup.sh`, pas de cron.** Ces lignes ont longtemps dit
« le code de retour EST l'alerte » : c'était faux. Le `-o pipefail` de la ligne
de cron préserve bien le code de sortie — sans lui le tube `backup.sh | logger`
rendrait celui de `logger`, toujours nul — mais **cron n'envoie un courriel que
si le travail produit de la sortie**, or tout part vers `logger` ; il n'y a ni
`MAILTO` ni MTA sur la machine. Une sauvegarde ratée ne réveillait donc
personne. C'est `backup.sh` qui alerte désormais, par le canal configuré dans
`/srv/carlys/alertes.env` (voir `_alert.sh`). Le code de retour reste juste et
utile pour qui appelle le script à la main. L'alerte
ne vaut que si elle ne crie pas pour rien : un environnement dont le
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

### La copie hors machine

Tout ce qui précède vit sur **le disque que les sauvegardes protègent** : un
disque mort, une machine perdue chez l'hébergeur, un rançongiciel ou un `rm`
de travers emportent les bases **et** leur historique. D'où une copie
**facultative mais signalée** vers un stockage S3 d'un autre fournisseur :
`carlysctl doctor` la réclame à chaque passage tant qu'elle manque, et la
compte comme un manque dès que la production est déployée.

Poser la cible, une fois (le bucket distant doit exister) :

```bash
sudo install -m 600 /dev/null /srv/carlys/sauvegarde-distante.env
sudo nano /srv/carlys/sauvegarde-distante.env   # modèle : infrastructure/server/env/sauvegarde-distante.env.example
sudo /srv/carlys/repo/scripts/server/backup.sh  # éprouver tout de suite
sudo /srv/carlys/repo/scripts/server/carlysctl doctor
```

Chaque nuit, après les sauvegardes locales, partent **chiffrés côté serveur**
(gpg, AES-256, phrase de passe du fichier) :

```
<bucket>/<préfixe>/<env>/postgres/<env>-<horodatage>.dump.gpg
<bucket>/<préfixe>/<env>/medias/medias-<horodatage>.tar.gpg
```

puis ce qui dépasse `CARLYS_SAUVEGARDE_DISTANTE_RETENTION_JOURS` (14 par
défaut) est effacé **côté distant**, sur les seuls dossiers qui viennent de
recevoir un envoi réussi — **toutes versions comprises** (`mc rm --versions`) :
sur un bucket versionné, un effacement simple ne pose qu'un marqueur, et le
dump, comptes supprimés compris, resterait lisible sans limite, contre les
16 jours que promet la politique de confidentialité. La clé d'accès doit donc
pouvoir effacer des versions. Pour mettre l'historique à l'abri d'une clé
volée, c'est le **verrouillage d'objets** (mode conformité) qui protège, pas
le versionnement seul — et pour une durée **égale** à la rétention, jamais
plus : au-delà, l'effacement échoue, l'envoi aussi, et l'alerte le dit. Le transfert passe par `mc`, dans l'image
`carlys-mc` déjà présente ; les identifiants lui arrivent par l'entrée
standard, jamais en ligne de commande. Un échec a **son** alerte (« Copie hors
machine: ECHEC »), distincte de celle des bases : la copie locale de la nuit
existe, c'est la redondance qui manque. Le raisonnement complet, dont le choix
de gpg plutôt qu'`openssl enc`, est en tête de `_hors_site.sh`.

**La phrase de passe se garde AUSSI hors de la machine** (gestionnaire de mots
de passe). C'est tout l'objet de la copie : le jour où elle sert, ce serveur
n'existe plus, et sans la phrase les fichiers distants sont illisibles.

### Restaurer depuis la copie hors machine

Sur n'importe quelle machine qui a `gpg` et `mc` (ou la console du
fournisseur) :

```bash
# 1. rapatrier la dernière copie (mc alias set distant <URL> puis clé et secret)
mc ls distant/<bucket>/<préfixe>/production/postgres/
mc cp distant/<bucket>/<préfixe>/production/postgres/production-<horodatage>.dump.gpg .
mc cp distant/<bucket>/<préfixe>/production/medias/medias-<horodatage>.tar.gpg .

# 2. déchiffrer (gpg demande la phrase de passe) — un fichier altéré refuse
#    de se déchiffrer, il ne rend jamais d'octets faux
gpg --output production.dump --decrypt production-<horodatage>.dump.gpg
mkdir medias && gpg --decrypt medias-<horodatage>.tar.gpg | tar -C medias -xf -

# 3. sur le serveur reconstruit (setup.sh, puis un premier déploiement du même sha) :
docker compose -p carlys_production --env-file /srv/carlys/production/.env \
  -f infrastructure/server/compose.yml exec -T postgres \
  pg_restore -U carlys -d carlys_production --clean --if-exists < production.dump
#    et les médias, dans le bucket public :
mc mirror --overwrite medias/ local/carlys-media
```

Le bucket **privé** des photos de repas n'est dans aucune sauvegarde, locale
ou distante (voir « Les médias aussi » ci-dessus) : c'est voulu, et c'est ce
que dit la politique de confidentialité.

## Variables

Aucune n'est nécessaire sur un serveur normal ; elles existent pour pouvoir
jouer ces scripts hors serveur, contre une arborescence jetable.

| Variable | Défaut | Rôle |
| --- | --- | --- |
| `CARLYS_ROOT` | `/srv/carlys` | racine des données |
| `CARLYS_COMPOSE_FILE` | `infrastructure/server/compose.yml` | fichier compose |
| `CARLYS_REGISTRY` | `ghcr.io/mimiflo` | préfixe complet des images ; le `.env` de l'environnement fait foi |
| `CARLYS_HEALTH_TRIES` / `CARLYS_HEALTH_DELAY` | `60` / `2` | attente de santé (bornée) |
| `CARLYS_BACKUP_RETENTION_DAYS` | `14` | rétention des dumps (et, par défaut, de la copie distante) |
| `CARLYS_DEPLOY_BACKUP` | oui en production, non en recette | dump de la base avant la migration ; lu aussi dans le `.env` |
| `CARLYS_BACKUP_PREMIGRATION_KEEP` | `3` | dumps d'avant-migration gardés par environnement |
| `CARLYS_BACKUP_PREMIGRATION_MAX_DAYS` | `30` | âge maximal d'un dump d'avant-migration, appliqué au déploiement et chaque nuit ; lu aussi dans le `.env` |
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

## Les essais

Ces scripts s'éprouvent SANS serveur ni démon Docker : `tests/lib.sh` leur
donne un `CARLYS_ROOT` jetable et un `docker` factice qui consigne chaque
appel.

| Essai | Ce qu'il vérifie |
| --- | --- |
| `tests/sauvegarde_test.sh` | le dump d'avant-migration (ordre, échec qui arrête tout, défauts par environnement), sa rétention en nombre ET en âge, au déploiement comme chaque nuit ; la copie chiffrée hors machine, avec de vrais `minio`, `mc` et `gpg`, jusqu'à la restauration ; l'avertissement de `doctor` |
| `tests/supervision_test.sh` | ce que la passe de supervision fait d'elle-même : le clone n'avance que jusqu'à un commit dont les images existent (CI verte), jamais par-dessus une modification locale ; les deux tâches quotidiennes (photos, purge des comptes) — rythme, réessai dans l'heure, alerte ouverte puis résolue, image antérieure à la commande, délai de purge du `.env` |
| `tests/compose_test.sh` | le compose tel que `docker compose config` le comprend : plafonds mémoire de la recette, tas de V8 de l'API sous le sien, Redis borné, base de production protégée du tueur de processus, réglages PostgreSQL |

`./scripts/check_infra.sh` les rejoue, avec `shellcheck`, les vhosts nginx
(`infrastructure/nginx/tests/`), l'ordre des Dockerfile et les portes de CI
(`scripts/ci/tests/`). Le workflow `infra-ci` fait de même à chaque poussée
qui touche ces fichiers ; un essai sauté faute d'outil y est un échec.

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
