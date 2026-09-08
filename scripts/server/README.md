# Scripts d'exploitation du serveur dédié

Quatre scripts, une machine Debian/Ubuntu, deux environnements (`staging` et
`production`) isolés par projet Compose et par volumes. Ils ne remplacent pas
la stratégie de déploiement — elle est écrite dans
[`infrastructure/deployment/README.md`](../../infrastructure/deployment/README.md)
— ils l'exécutent.

| Script | Quand | Ce qu'il fait |
| --- | --- | --- |
| `setup.sh` | une fois, puis à chaque fois qu'une brique est ajoutée | prépare la machine : docker + plugin compose, nginx, certbot, ufw (22/80/443), `/srv/carlys`, copie des `.env` d'exemple, cron de sauvegarde. **Idempotent.** |
| `deploy.sh` | à chaque livraison en recette | `deploy.sh <staging\|production> <sha>` : pull des trois images, migration, bascule, santé, retour arrière si besoin |
| `promote.sh` | pour une mise en production | rejoue en production **le sha déjà validé en recette**, après vérification du registre et confirmation humaine |
| `backup.sh` | tous les jours, par cron | `pg_dump` des deux bases, horodaté, rétention 14 jours |

`_common.sh` n'est pas un script : c'est la bibliothèque partagée (chemins,
lecture du journal `DEPLOYED`, appel de Compose, attente HTTP bornée). Elle
existe pour que ces règles ne soient écrites qu'une fois — `promote.sh` lit le
`DEPLOYED` que `deploy.sh` écrit.

## Ce qu'ils supposent

- le dépôt cloné sur le serveur (ils lisent `infrastructure/server/compose.yml`
  et `infrastructure/server/env/*.env.example`) ;
- l'arborescence du contrat de conception :

```
/srv/carlys/
  staging/.env        production/.env        # secrets, mode 600
  staging/DEPLOYED    production/DEPLOYED    # journal tenu par deploy.sh
  backups/                                   # dumps, mode 700
  ghcr.token                                 # PAT read:packages, mode 600
```

- les images publiées sous `ghcr.io/mimiflo/` et taguées `sha-<12 caractères>` ;
  l'admin de **production** porte en plus le suffixe `-prod` (garde légale
  armée), et c'est la seule différence entre les deux environnements.

## Le déploiement, dans l'ordre

```bash
scripts/server/deploy.sh staging 4f2a91c0be77
```

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
fichier est écrit en `.part` puis renommé après vérification de la signature
`PGDMP` — une sauvegarde interrompue ne laisse jamais un fichier d'apparence
normale. La purge ne touche que les fichiers `staging-*.dump` et
`production-*.dump` de plus de 14 jours : ce qu'un opérateur a déposé là ne
disparaît pas.

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
absent de tout `up -d`), appelé en `run --rm --no-deps` : réseau,
`DATABASE_URL` et fichier d'environnement y sont déjà décrits, et une seconde
description finirait par diverger de la première.

## Ce qu'ils n'automatisent pas

DNS, achat du domaine, certificats certbot (le DNS doit résoudre d'abord),
vraies valeurs des secrets, remplissage des marqueurs légaux, comptes des
magasins d'applications. `setup.sh` termine en les listant.
