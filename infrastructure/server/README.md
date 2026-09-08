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
  **modèles versionnés** : ils ne contiennent que des valeurs factices
  (`CHANGE_MOI_…`) et le jeton `DOMAIN`. Les vrais fichiers vivent sur le
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
comm -23 \
  <(grep -oE '^    [A-Z][A-Z0-9_]*:' apps/api/src/config/env.schema.ts | tr -d ' :' | sort -u) \
  <(grep -oE '^#? *[A-Z][A-Z0-9_]*=' infrastructure/server/env/staging.env.example \
      | tr -d '# =' | sort -u)
```

Le second `grep` compte aussi les lignes commentées : une variable facultative
laissée commentée EST documentée.

## Épingler une image d'infrastructure

Les versions de PostgreSQL, Redis, MinIO, `mc` et Mailpit sont épinglées dans
`compose.yml` (valeurs par défaut de `CARLYS_POSTGRES_IMAGE`,
`CARLYS_REDIS_IMAGE`, `CARLYS_MINIO_IMAGE`, `CARLYS_MC_IMAGE`,
`CARLYS_MAILPIT_IMAGE`). Elles ne figurent pas dans les `.env` : elles sont les
mêmes pour les deux environnements, donc leur place est dans le fichier
versionné. Pour tester une montée de version sur la seule recette, poser la
variable dans le `.env` de recette suffit à couvrir le défaut.
