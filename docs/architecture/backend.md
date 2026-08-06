# Architecture — API NestJS (`apps/api`)

L'API Carlys est un **monolithe modulaire** NestJS 11 en TypeScript strict :
une seule application déployable, découpée en modules aux frontières nettes.
Ce document décrit la structure réellement en place à l'Étape 1 (fondation)
et la structure cible vers laquelle les étapes suivantes convergent.

Vue d'ensemble de la plateforme : [overview.md](./overview.md).
Conventions HTTP (enveloppes, pagination, codes d'erreur) :
[`docs/api/README.md`](../api/README.md).

## Arborescence `src/` — état actuel (Étape 1)

```text
apps/api/src
├── main.ts                        # bootstrap : logger, body parser 1 Mo, Swagger, listen
├── app/
│   ├── app.module.ts              # module racine : Pino, Throttler, filtres/intercepteurs globaux
│   └── configure-app.ts           # config HTTP partagée bootstrap ⇄ tests e2e
├── config/
│   ├── env.schema.ts              # schéma Zod des variables d'environnement
│   ├── app-config.module.ts       # ConfigModule global (validate: validateEnv)
│   └── app-config.service.ts      # accès typé à la configuration validée
├── common/
│   ├── filters/
│   │   └── all-exceptions.filter.ts        # → enveloppe { error: … }
│   ├── interceptors/
│   │   └── response-envelope.interceptor.ts # → enveloppe { data, meta, requestId }
│   ├── types/
│   │   └── request-with-id.ts
│   └── utilities/
│       └── with-timeout.ts
├── database/
│   └── prisma/
│       ├── prisma.module.ts       # module global
│       └── prisma.service.ts      # unique point d'accès PrismaClient
├── infrastructure/
│   └── cache/
│       ├── redis.module.ts        # module global
│       └── redis.service.ts       # client ioredis partagé (lazyConnect)
└── modules/
    ├── health/                    # /health, /health/live, /health/ready
    │   ├── health.controller.ts
    │   ├── health.service.ts
    │   └── probes/                # database.probe.ts, redis.probe.ts
    └── metrics/                   # /metrics (prom-client)
        ├── metrics.controller.ts
        ├── metrics.service.ts
        └── metrics-auth.guard.ts  # Bearer METRICS_TOKEN en production
```

Rôle de chaque dossier racine :

| Dossier | Rôle |
| --- | --- |
| `app/` | Assemblage de l'application : module racine et configuration HTTP commune. |
| `config/` | Configuration validée par Zod, exposée uniquement via `AppConfigService` (aucun module ne lit `process.env` directement). |
| `common/` | Transverse HTTP : filtre d'exceptions, intercepteur d'enveloppe, types et utilitaires partagés. |
| `database/` | Accès aux données : `PrismaService` (et, à terme, les repositories transverses). |
| `infrastructure/` | Adaptateurs techniques : cache Redis aujourd'hui ; files BullMQ, stockage objet, e-mail… demain (cible). |
| `modules/` | Modules fonctionnels. Étape 1 : `health` et `metrics` uniquement. |

## Arborescence cible — modules métier

Les modules métier arrivent par tranches verticales. Cible du dossier
`modules/` à terme (aucun de ces modules n'existe encore, sauf `health` et
`metrics`) :

```text
src/modules/
├── health/               # Étape 1 (fait)
├── metrics/              # Étape 1 (fait)
├── auth/                 # Étape 2 — JWT access court + refresh rotatif hashé, Argon2id
├── users/                # Étape 2
├── profiles/             # Étape 2
├── devices/              # Étape 2 — sessions par appareil, détection de réutilisation
├── exercises/            # Étape 3 — + seed 30+ exercices, cache Redis
├── muscle_groups/        # Étape 3
├── media/                # Étape 3 — premiers médias d'exercices, via StorageProvider (voir plus bas)
├── programs/             # Étape 4
├── workout_templates/    # Étape 4
├── workout_sessions/     # Étape 4 — synchronisation offline-first idempotente
├── workout_sets/         # Étape 4
├── progress/             # Étape 5
├── body_metrics/         # Étape 5
├── subscriptions/        # Étape 6 — Stripe web, RevenueCat possible
├── entitlements/         # Étape 6 — autorité côté serveur
├── notifications/        # avec l'intégration FCM réelle (au plus tôt Étape 4)
├── health_integrations/  # post-MVP
├── coaches/              # post-MVP
├── social/               # post-MVP
├── reports/              # Étape 7
├── audit/                # Étape 7
└── admin/                # Étape 7 — rôles, permissions, audit
```

## Structure interne d'un module métier (cible)

Un module riche en logique métier suit un découpage en quatre couches :

```text
modules/<module>/
├── application/           # orchestration des cas d'usage
│   ├── commands/          # écritures (ex. StartWorkoutSessionCommand)
│   ├── queries/           # lectures (ex. ListExercisesQuery)
│   ├── dto/               # objets de transfert internes à la couche application
│   └── services/          # services applicatifs (orchestrent domaine + infra)
├── domain/                # cœur métier, sans dépendance NestJS/Prisma
│   ├── entities/
│   ├── enums/
│   ├── events/            # événements de domaine
│   ├── repositories/      # interfaces (ports) — implémentées dans infrastructure/
│   ├── services/          # règles métier pures
│   └── value-objects/
├── infrastructure/        # adaptateurs concrets
│   ├── persistence/       # repositories Prisma (implémentations)
│   ├── providers/         # intégrations externes (Stripe, FCM, stockage…)
│   └── mappers/           # modèle Prisma ⇄ entité de domaine
└── presentation/
    └── http/
        ├── controllers/   # routes, aucune logique métier
        ├── dto/           # DTO d'entrée validés (class-validator)
        └── presenters/    # mise en forme des réponses (avant enveloppe)
```

**Pragmatisme avant tout.** Ce découpage complet se justifie pour les modules
à forte logique métier (`auth`, `workout_sessions`, `subscriptions`). Pour un
CRUD simple (`muscle_groups` par exemple), un module aplati
`controller + service + dto + repository` est parfaitement acceptable : on
n'introduit une couche que lorsqu'elle paie sa complexité. Les modules
`health` et `metrics` de l'Étape 1 illustrent cette forme minimale.

## Règles d'architecture

1. **Les contrôleurs ne contiennent aucune logique métier** : ils valident
   l'entrée (DTO), délèguent au service, retournent le résultat. Jamais
   d'accès Prisma direct depuis un contrôleur.
2. **Prisma n'est accessible que via `PrismaService`** (`src/database/prisma`),
   et uniquement depuis les repositories/services — dans `database/` pour le
   transverse, dans `infrastructure/persistence/` du module pour le métier.
3. **Les interfaces de repositories vivent dans le domaine**, leurs
   implémentations Prisma dans l'infrastructure du module : le domaine ne
   dépend jamais de Prisma.
4. **Transactions courtes** : une transaction Prisma englobe le strict
   nécessaire (écritures cohérentes), jamais d'appel réseau externe (HTTP,
   e-mail, stockage) à l'intérieur d'une transaction.
5. **Aucun module ne lit `process.env`** : toute configuration passe par
   `AppConfigService` (donc par le schéma Zod).
6. **Les contrats publics vivent dans `packages/api-contracts`** (schémas Zod
   des enveloppes, contrats `/health`) et sont partagés avec les clients
   TypeScript.

## Pipeline d'une requête

Ordre effectif des étapes pour une requête `/api/v1/…` :

```text
requête HTTP
  │
  1. pino-http (nestjs-pino) : requestId — reprend l'en-tête x-request-id
     entrant s'il est valide ([\w-]{1,64}), sinon génère un UUID ;
     l'en-tête est renvoyé sur la réponse, le log est corrélé
  2. helmet + CORS (origines issues de CORS_ORIGINS)
  3. body parser JSON/urlencoded, limité à 1 Mo (MAX_JSON_BODY_SIZE)
  4. ThrottlerGuard global : 100 requêtes / 60 s par défaut → 429 sinon
  5. ValidationPipe global : whitelist + forbidNonWhitelisted + transform
     → 400 VALIDATION_ERROR si le DTO est invalide
  6. contrôleur → service applicatif → domaine → repository (Prisma)
  7. ResponseEnvelopeInterceptor : enveloppe { data, meta, requestId }
     (routes /api/… uniquement ; /health et /metrics restent bruts)
  8. AllExceptionsFilter (en cas d'exception, à n'importe quelle étape) :
     enveloppe { error: { code, message, details, requestId } } ;
     les 5xx sont journalisées et leur message est masqué au client
  │
réponse HTTP (+ en-tête x-request-id)
```

`configure-app.ts` regroupe cette configuration HTTP et est utilisé à
l'identique par `main.ts` et par les tests e2e : les tests exercent la même
application que la production.

## Configuration : Zod refuse de démarrer

`src/config/env.schema.ts` valide **toutes** les variables d'environnement au
bootstrap via `ConfigModule`. Si une variable essentielle est absente ou
invalide, `validateEnv` lève une erreur listant chaque problème et **le
serveur refuse de démarrer** :

```text
Configuration invalide — démarrage refusé.
  - DATABASE_URL: DATABASE_URL doit être une URL de connexion PostgreSQL (postgresql://…)
```

Variables validées (Étape 1) :

| Variable | Contrainte | Défaut |
| --- | --- | --- |
| `NODE_ENV` | `development \| test \| staging \| production` | `development` |
| `PORT` | entier 1–65535 | `3000` |
| `DATABASE_URL` | URL `postgresql://` ou `postgres://` | **requis** |
| `REDIS_URL` | URL `redis://` ou `rediss://` | **requis** |
| `CORS_ORIGINS` | liste d'origines séparées par des virgules | `http://localhost:3001` |
| `LOG_LEVEL` | niveau Pino | `info` |
| `RATE_LIMIT_TTL_SECONDS` / `RATE_LIMIT_MAX_REQUESTS` | entiers positifs | `60` / `100` |
| `SWAGGER_ENABLED` | `true \| false` | activé hors production |
| `METRICS_TOKEN` | ≥ 16 caractères | optionnel (requis pour `/metrics` en production) |

Les secrets d'étapes futures (JWT, Stripe, S3…) seront ajoutés **dans ce
schéma** au moment où le code qui les consomme arrive — jamais avant.

## Observabilité

- **Logs structurés Pino** (`nestjs-pino`) : JSON en production,
  `pino-pretty` en développement. Chaque ligne porte le `requestId` ; les
  en-têtes `authorization` et `cookie` sont expurgés ; les requêtes
  `/health*` et `/metrics` ne sont pas auto-journalisées. Une exception 5xx
  est journalisée avec sa stack, mais le client ne reçoit qu'un message
  générique.
- **`/metrics`** (prom-client) : métriques Prometheus par défaut du process
  Node. Libre hors production ; en production, exige `Bearer METRICS_TOKEN`
  (comparaison à temps constant) et répond 404 si le token n'est pas
  configuré — l'endpoint se comporte comme inexistant.
- **Sondes** : `/health/live` (le processus répond, sans dépendance) et
  `/health/ready` (PostgreSQL + Redis joignables, avec latence par
  composant) pilotent les orchestrateurs et la bascule de trafic au
  déploiement.
- **Sentry (cible)** : le suivi d'erreurs applicatif sera branché avec sa
  configuration réelle (DSN validé dans `env.schema.ts`) — aucune dépendance
  morte n'est installée en attendant.

## Performances

- **Pagination par curseur** partout où une liste peut grandir : jamais
  d'`OFFSET` profond. Limites `20` par défaut, `100` maximum
  (`@carlys/shared-config`), méta `nextCursor`/`hasMore` — voir
  [`docs/api/README.md`](../api/README.md).
- **Cache Redis ciblé** (cible, dès l'Étape 3). On ne met en cache que des
  données partagées, peu changeantes et invalidables proprement :
  exercices publics, groupes musculaires, programmes publics, configuration
  distante. **Jamais** : séance active d'un utilisateur, données de paiement
  ou d'entitlement — le serveur reste l'unique source d'autorité et ces
  données ne tolèrent aucune obsolescence.
- **BullMQ (cible)** pour les tâches lourdes ou différables : traitement de
  médias, envoi d'e-mails/notifications, traitement asynchrone de webhooks.
  Le client Redis partagé (`infrastructure/cache`) servira de connexion.
  Jamais de travail lourd dans le cycle requête/réponse.
- **Graceful shutdown** : `enableShutdownHooks()` est actif ; à l'arrêt,
  Prisma se déconnecte (`onModuleDestroy`) et le client Redis fait un `quit`
  propre. L'API démarre même si PostgreSQL ou Redis est indisponible
  (connexions paresseuses/tolérantes) : c'est `/health/ready` qui signale la
  panne, pas un crash au boot.
- **Migrations hors du boot** : `prisma migrate deploy` s'exécute comme étape
  de déploiement distincte, avant la bascule du trafic — jamais au démarrage
  du conteneur.

## Stockage des médias : interface `StorageProvider` (cible)

Le module `media` (cible) ne manipulera jamais un SDK de stockage
directement : il dépendra d'une interface `StorageProvider` (port du
domaine), avec une implémentation par environnement :

| Implémentation | Usage |
| --- | --- |
| `LocalStorageProvider` | tests / dépannage local (système de fichiers) |
| `S3StorageProvider` | MinIO en développement (bucket `carlys-media` créé par `minio-init` dans `docker-compose.yml`), S3 managé en staging/production |
| `CloudflareR2StorageProvider` | alternative production (API compatible S3) |

Contrat envisagé : URLs présignées pour l'upload direct depuis les clients
(l'API ne relaie pas les octets), génération d'URL de lecture, suppression.
L'implémentation est choisie par la configuration validée au démarrage, comme
tout le reste.
