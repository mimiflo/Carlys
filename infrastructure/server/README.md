# `infrastructure/server/` — la pile Docker du serveur dédié

Trois fichiers, et rien d'autre : le **quoi** faire tourner sur le serveur.
Le **comment** l'y installer et l'y déployer vit dans `scripts/server/`.

| Fichier | Rôle |
| --- | --- |
| `compose.yml` | la pile complète — PostgreSQL, Redis, MinIO (+ initialisation du bucket), API, application web, et Mailpit en recette |
| `env/staging.env.example` | modèle du `.env` de recette, à copier dans `/srv/carlys/staging/.env` |
| `env/production.env.example` | modèle du `.env` de production, à copier dans `/srv/carlys/production/.env` |

## Ce que ces fichiers NE sont pas

- **Pas l'environnement de développement.** Celui-là est le `docker-compose.yml`
  de la racine : ports ouverts sur l'hôte, secrets factices, images construites
  sur place. Ici les images viennent du registre, taguées par SHA, et rien
  n'écoute ailleurs que sur `127.0.0.1`.
- **Pas des fichiers de configuration.** Les `*.env.example` sont des
  **modèles versionnés** : chaque valeur y est factice et le dit
  (`CHANGE_MOI_…`, `DOMAIN` compris). Les vrais fichiers vivent sur le
  serveur, hors du dépôt, en `chmod 600`.
- **Pas un script de déploiement.** `compose.yml` ne sait ni migrer, ni
  attendre `/health/ready`, ni revenir en arrière : c'est le travail de
  `deploy.sh`.
- **Pas la configuration nginx.** Le serveur web tourne sur l'hôte, pas en
  conteneur : voir `infrastructure/nginx/`.

## Un seul fichier pour deux environnements

Recette et production partagent `compose.yml` ; tout ce qui les distingue tient
dans leur `.env` — nom de projet compose, ports d'écoute sur la boucle locale,
domaines, secrets, tag d'image, persistance Redis, profil Mailpit. Deux fichiers
jumeaux divergeraient au troisième correctif ; un seul ne le peut pas.

```bash
docker compose --env-file /srv/carlys/staging/.env \
               -f infrastructure/server/compose.yml up -d
```

L'isolation entre les deux piles est portée par `COMPOSE_PROJECT_NAME`
(`carlys_staging` / `carlys_production`) : conteneurs, réseau et volumes en
héritent le préfixe, et les deux tournent côte à côte sur le même hôte sans se
voir.

Le **domaine** est la seule chose à saisir pour déplacer la pile : `DOMAIN`
ouvre les deux `.env`, et `CORS_ORIGINS`, `S3_PUBLIC_BASE_URL`, `EMAIL_FROM` et
`PUBLIC_APP_URL` en dérivent (`https://app-staging.${DOMAIN}`, …). Les
sous-domaines eux-mêmes sont fixés par le contrat de conception et ne se
paramètrent pas. `scripts/server/setup.sh` relit cette même variable pour
énumérer les enregistrements DNS à poser : un seul endroit, une seule vérité.

## Cinq choses à savoir avant d'y toucher

**Les migrations ne sont pas un service.** Le service `migrate` est derrière le
profil `migrate` : un `docker compose up -d` ne le démarre jamais. `deploy.sh`
le lance en tâche ponctuelle AVANT la bascule du trafic, et un code de retour
non nul arrête le déploiement (`infrastructure/deployment/README.md`).

```bash
docker compose --env-file <.env> -f infrastructure/server/compose.yml \
  run --rm migrate            # `run` active le profil de lui-même
```

**Une variable facultative se laisse commentée, jamais vide.** `CLE=` arrive
dans le conteneur comme chaîne vide, que le schéma Zod de l'API rejette :
l'API refuserait de démarrer. Commentée, elle est simplement absente — ce
qu'`.optional()` accepte.

**`PGTZ` n'est pas décoratif.** Les 99 colonnes `DateTime` du schéma Prisma sont
des `TIMESTAMP(3)` *sans* fuseau : « les dates sont stockées en UTC » ne tient
qu'au fuseau du serveur et de la session. `TZ` et `PGTZ` le fixent, les deux.

**`CARLYS_ADMIN_TAG_SUFFIX` doit être DÉCLARÉE, même vide.** Le compose écrit
`${CARLYS_ADMIN_TAG_SUFFIX?…}` — point d'interrogation, pas tiret. La recette
la pose vide, la production à `-prod` ; si la ligne DISPARAÎT d'un `.env`,
compose refuse de résoudre au lieu de retomber sur la chaîne vide. C'est la
différence entre un déploiement qui s'arrête et une production qui sert
silencieusement l'image de recette, garde légale desserrée et mentions légales
à trous. Le message d'erreur nomme la variable :

```
error while interpolating services.admin.image: required variable
CARLYS_ADMIN_TAG_SUFFIX is missing a value: …
```

**`up -d` échoue si le bucket n'a pas pu être créé.** L'API dépend de
`minio-init` en `service_completed_successfully`. Sans cette dépendance,
personne n'attendait la tâche : elle pouvait sortir en erreur — nom de bucket
invalide, identifiants MinIO faux — pendant que `up -d` rendait 0 et que l'API
partait déposer ses médias dans un bucket inexistant. Un déploiement s'arrête
désormais dessus, et le message le dit :

```
service "minio-init" didn't complete successfully: exit 1
```

Corollaire d'exploitation : MinIO doit être joignable et ses identifiants
justes pour que l'API démarre. C'est le bon ordre — un serveur de médias muet
n'est pas un détail qu'on découvre au premier envoi de photo.

## Vérifier que les `.env.example` sont complets

La liste des variables de l'API est celle de `apps/api/src/config/env.schema.ts`,
et cette liste-là bouge. Elle se compte, elle ne se recopie pas — sortie vide
attendue, pour chaque environnement :

```bash
# L'assertion de comptage n'est pas un ornement. Le `comm` ci-dessous rend une
# sortie vide dans DEUX cas qui se ressemblent : tout est documenté, ou
# l'extraction du schéma n'a rien trouvé (indentation changée, fichier
# déplacé, schéma découpé en plusieurs fichiers). Un filet dont l'échec
# ressemble au succès n'est pas un filet ; le compte les sépare.
schema=$(grep -oE '^    [A-Z][A-Z0-9_]*:' apps/api/src/config/env.schema.ts \
           | tr -d ' :' | sort -u)
n=$(printf '%s\n' "$schema" | grep -c .)
[ "$n" -ge 40 ] || {
  echo "EXTRACTION CASSÉE : $n variables lues dans env.schema.ts (49 le 8 septembre 2026)" >&2
  false
}

for env in staging production; do
  comm -23 <(printf '%s\n' "$schema") \
           <(grep -oE '^#? *[A-Z][A-Z0-9_]*=' "infrastructure/server/env/$env.env.example" \
               | tr -d '# =' | sort -u)
done
```

Le second `grep` compte aussi les lignes commentées : une variable facultative
laissée commentée EST documentée.

## La base du serveur ne reçoit AUCUN script d'initialisation

Le `docker-compose.yml` de développement monte
`infrastructure/database/init/` dans `/docker-entrypoint-initdb.d` : PostgreSQL
y joue `01-init.sql` au premier démarrage, qui pose l'extension `citext` et
crée la base `carlys_test`. **Ce montage n'existe pas ici**, et c'est
volontaire : sur le serveur, `prisma migrate deploy` est le SEUL à écrire dans
le schéma.

Rien ne manque pour autant, et cela se vérifie :

- **`citext` n'est utilisée par aucune migration.** `grep -r 'CREATE EXTENSION'
  apps/api/prisma/migrations/` ne rend rien, et la colonne des adresses est
  `"email" TEXT NOT NULL` avec un index `UNIQUE` ordinaire
  (`20260806180000_auth_foundation/migration.sql`). L'insensibilité à la casse
  est obtenue **dans l'application**, par `normalizeEmail()`
  (`apps/api/src/modules/auth/application/auth.service.ts`), et les recherches
  du back-office passent par `mode: 'insensitive'`, c'est-à-dire `ILIKE` — qui
  ne réclame aucune extension. Les UUID, eux, sont engendrés côté client par
  Prisma (`@default(uuid())`), jamais par `gen_random_uuid()`.
- **`carlys_test` ne sert qu'aux tests d'intégration**, qui ne tournent pas sur
  le serveur.

Une migration future qui aurait besoin d'une extension devra donc la poser
elle-même (`CREATE EXTENSION IF NOT EXISTS …` dans son `migration.sql`) : sur
le serveur, il n'y a pas de script d'amorçage pour la lui offrir.

> `docs/database/schema.md` décrit encore les e-mails comme des colonnes
> `citext` à index unique partiel. C'est une dérive de documentation par
> rapport au schéma réellement migré, pas une dépendance de la pile serveur.

## Épingler une image d'infrastructure

Les versions de PostgreSQL, Redis, MinIO, `mc` et Mailpit sont épinglées dans
`compose.yml` (valeurs par défaut de `CARLYS_POSTGRES_IMAGE`,
`CARLYS_REDIS_IMAGE`, `CARLYS_MINIO_IMAGE`, `CARLYS_MC_IMAGE`,
`CARLYS_MAILPIT_IMAGE`). Elles ne figurent pas dans les `.env` : elles sont les
mêmes pour les deux environnements, donc leur place est dans le fichier
versionné. Pour tester une montée de version sur la seule recette, poser la
variable dans le `.env` de recette suffit à couvrir le défaut.

MinIO et `mc` viennent de **quay.io**, épinglés par empreinte en plus du tag :
MinIO a cessé de distribuer ses images en octobre 2025 et les dépôts
`minio/minio` et `minio/mc` ont disparu de Docker Hub — même tag épinglé, plus
rien à tirer. Le projet étant gelé, ces deux versions sont définitives ; si
quay.io les retirait à son tour, `CARLYS_MINIO_IMAGE` et `CARLYS_MC_IMAGE`
pointent vers n'importe quel miroir sans modifier `compose.yml`.
