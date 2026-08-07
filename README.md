# Carlys

Plateforme fitness SaaS multiplateforme — application mobile Flutter (iOS & Android), API NestJS et tableau de bord d'administration Next.js, dans un monorepo unique.

> **État actuel : Étapes 1 (fondation), 2 (authentification), 3 (exercices) et 4 (séances offline-first) terminées.** Les fonctionnalités métier arrivent par tranches verticales — voir [État du projet](#état-du-projet).

---

## Vision du produit

Carlys est une application d'entraînement destinée à l'App Store et à Google Play :

- **Comptes utilisateurs** et sessions par appareil (Étape 2) ;
- **Bibliothèque d'exercices** enrichie et filtrable (Étape 3) ;
- **Programmes et séances** : séries, répétitions, charges, minuteur de repos (Étape 4) ;
- **Offline-first** : les séances s'enregistrent localement (Drift/SQLite) puis se synchronisent via une file idempotente dès que le réseau revient (Étape 4) ;
- **Progression** : records personnels, historique, graphiques (Étape 5) ;
- **Premium** : entitlements calculés côté serveur, achats in-app (RevenueCat possible) et Stripe sur le web (Étape 6) ;
- **Administration** : back-office avec rôles, permissions et journal d'audit (Étape 7).

L'Étape 1 pose la fondation : monorepo outillé, API durcie (sécurité, observabilité, contrats de réponse), design system mobile complet, infrastructure Docker locale et CI.

## Stack technique

| Application | Rôle | Technologies principales |
| --- | --- | --- |
| `apps/api` | Backend (monolithe modulaire) | NestJS 11, TypeScript strict, Prisma 6 + PostgreSQL 17, Redis (ioredis), Pino (`nestjs-pino`), Helmet, `@nestjs/throttler`, class-validator, Zod (validation de la config), Swagger, Jest |
| `apps/admin` | Tableau de bord d'administration | Next.js 16 (App Router), TypeScript, Tailwind CSS v4, TanStack Query, React Hook Form + Zod, Vitest + Testing Library |
| `apps/mobile` | Application mobile iOS/Android | Flutter, Riverpod (+ annotations), GoRouter, Dio, Drift/SQLite, Freezed, json_serializable, flutter_secure_storage, connectivity_plus, fl_chart, Rive |
| `packages/*` | Code partagé TypeScript | Zod (contrats d'API), tokens de design (JSON), configs TypeScript/ESLint, constantes partagées |

Points structurants de l'API :

- versioning URI : tous les endpoints métier sous **`/api/v1`** ;
- enveloppes de réponse normalisées `{ data, meta, requestId }` et `{ error: { code, message, details, requestId } }` (schémas Zod dans `packages/api-contracts`) ;
- configuration validée par Zod au démarrage (`apps/api/src/config/env.schema.ts`) : le serveur **refuse de démarrer** si une variable essentielle manque ;
- endpoints techniques `/health`, `/health/live`, `/health/ready` et `/metrics` (Prometheus, protégé par un Bearer `METRICS_TOKEN` en production) ;
- Swagger sur `/api/docs` (désactivé en production).

## Architecture du monorepo

Monorepo **pnpm workspaces** pour les projets TypeScript. L'application Flutter est **volontairement hors workspace JS** (outillage Dart indépendant).

```text
Carlys/
├── apps/
│   ├── api/                  # API NestJS (@carlys/api) — port 3000
│   │   ├── prisma/           # schema.prisma (modèles ajoutés par tranches), seed
│   │   ├── src/              # modules, config (env.schema.ts), health, metrics…
│   │   ├── test/             # tests e2e (Jest + supertest)
│   │   └── Dockerfile        # multi-stage, contexte = racine du monorepo
│   ├── admin/                # Admin Next.js (@carlys/admin) — port 3001
│   │   ├── src/              # App Router : / (statut plateforme), /login (documenté)
│   │   └── Dockerfile        # output standalone
│   └── mobile/               # Application Flutter (hors workspace pnpm)
│       ├── lib/
│       │   ├── app/          # bootstrap, environnement, routeur, observers
│       │   ├── core/         # api, auth, database, network, sync, erreurs…
│       │   ├── design_system/# couleurs, typo, espacements, thèmes, composants
│       │   ├── features/     # <feature>/{data,domain,presentation}
│       │   └── shared/       # éléments transverses
│       ├── test/             # tests unitaires et de widgets
│       └── integration_test/
├── packages/
│   ├── api-contracts/        # schémas Zod : enveloppes de réponse, health
│   ├── design-tokens/        # src/tokens.json = SOURCE DE VÉRITÉ du design
│   ├── eslint-config/        # flat config ESLint 9 + typescript-eslint strict
│   ├── shared-config/        # constantes : /api, v1, x-request-id, pagination…
│   └── typescript-config/    # base/library/nestjs/nextjs (strict)
├── infrastructure/
│   ├── database/init/        # 01-init.sql (extension citext + base carlys_test)
│   ├── docker/               # documentation des images
│   ├── nginx/                # reverse proxy staging/production (documentation)
│   ├── monitoring/           # observabilité : état actuel et cible
│   └── deployment/           # stratégie de déploiement
├── docs/                     # documentation détaillée (voir fin de ce fichier)
├── scripts/                  # setup.sh, check.sh, bootstrap_mobile.sh
├── .github/workflows/        # api-ci, admin-ci, mobile-ci, security-ci
├── docker-compose.yml        # PostgreSQL, Redis, Mailpit, MinIO (+ profil "app")
└── .env.example              # variables du docker-compose (valeurs factices)
```

Le design system Flutter (`AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppShadows`, `AppMotion`, `AppTheme` clair/sombre/OLED, `AppBreakpoints`, `AppIcons`, composants `AppButton`, `AppLoadingIndicator`, `AppErrorState`, `AppEmptyState`) reflète les valeurs de `packages/design-tokens/src/tokens.json` (primaire `#5B5BF6`, accent `#C6F432`, espacements 4→64, radius, typo, ombres, motion, breakpoints).

## Prérequis

| Outil | Version | Remarque |
| --- | --- | --- |
| Node.js | >= 22 | champ `engines` du `package.json` racine |
| pnpm | 10 | `corepack enable` suffit (`packageManager: pnpm@10.x`) |
| Docker + Docker Compose | récent | infrastructure locale (PostgreSQL, Redis, Mailpit, MinIO) |
| Flutter SDK | stable (Dart >= 3.6) | uniquement pour `apps/mobile` |

## Installation

### Option A — script d'installation

```bash
./scripts/setup.sh
```

Le script vérifie les prérequis, copie les fichiers `.env.example`, exécute `pnpm install`, build les packages partagés, démarre l'infrastructure Docker et génère le client Prisma.

### Option B — étapes manuelles

```bash
# 1. Fichiers d'environnement (valeurs factices adaptées au dev local)
cp .env.example .env
cp apps/api/.env.example apps/api/.env
cp apps/admin/.env.example apps/admin/.env.local

# 2. Dépendances TypeScript
pnpm install

# 3. Build des packages partagés (consommés par api et admin)
pnpm --filter "./packages/**" build

# 4. Infrastructure locale : PostgreSQL, Redis, Mailpit, MinIO
docker compose up -d

# 5. Client Prisma
pnpm prisma:generate
```

### Application mobile (optionnel, nécessite le SDK Flutter)

```bash
./scripts/bootstrap_mobile.sh
```

Ce script génère les dossiers de plateformes `android/` et `ios/` via `flutter create` (org `com.carlys`, projet `carlys_mobile`), puis exécute `flutter pub get` et `flutter analyze`. Les dossiers de plateformes ne sont pas versionnés : ils se régénèrent à la demande.

## Variables d'environnement

Toutes les valeurs des `.env.example` sont **factices** et adaptées au développement local. Ne jamais commiter de vrai secret (voir [SECURITY.md](./SECURITY.md)).

### `.env` (racine — consommé par `docker-compose.yml`)

| Variable | Description | Exemple (factice) |
| --- | --- | --- |
| `POSTGRES_USER` | Utilisateur PostgreSQL du conteneur | `carlys` |
| `POSTGRES_PASSWORD` | Mot de passe PostgreSQL | `carlys_dev_password` |
| `POSTGRES_DB` | Base de développement | `carlys_dev` |
| `MINIO_ROOT_USER` | Identifiant MinIO | `carlys-dev` |
| `MINIO_ROOT_PASSWORD` | Secret MinIO | `carlys-dev-secret` |
| `S3_ENDPOINT` | Endpoint S3 local | `http://localhost:9000` |
| `S3_BUCKET_MEDIA` | Bucket des médias (créé par `minio-init`) | `carlys-media` |
| `SMTP_HOST` / `SMTP_PORT` | SMTP de dev (Mailpit, UI sur `http://localhost:8025`) | `localhost` / `1025` |

### `apps/api/.env`

| Variable | Description | Exemple (factice) |
| --- | --- | --- |
| `NODE_ENV` | `development` \| `test` \| `staging` \| `production` | `development` |
| `PORT` | Port HTTP de l'API | `3000` |
| `DATABASE_URL` | Connexion PostgreSQL | `postgresql://carlys:carlys_dev_password@localhost:5432/carlys_dev` |
| `REDIS_URL` | Connexion Redis | `redis://localhost:6379` |
| `CORS_ORIGINS` | Origines autorisées, séparées par des virgules | `http://localhost:3001` |
| `LOG_LEVEL` | `fatal`…`trace` \| `silent` | `debug` |
| `RATE_LIMIT_TTL_SECONDS` | Fenêtre du rate limiting | `60` |
| `RATE_LIMIT_MAX_REQUESTS` | Requêtes max par fenêtre | `100` |
| `SWAGGER_ENABLED` | Optionnel — Swagger actif par défaut hors production | `true` |
| `METRICS_TOKEN` | Requis en production pour exposer `/metrics` (min. 16 caractères) | `jeton-factice-a-remplacer` |
| `JWT_ACCESS_SECRET` | **Requis** (≥ 32 caractères) — signature des access tokens | `openssl rand -base64 48` |
| `JWT_ACCESS_TTL_SECONDS` | Durée de vie de l'access token | `900` |
| `JWT_ISSUER` / `JWT_AUDIENCE` | Claims vérifiés à chaque requête | `carlys-api` / `carlys-mobile` |
| `REFRESH_TOKEN_TTL_DAYS` | Durée de vie (glissante) des sessions | `30` |
| `AUTH_MAX_LOGIN_ATTEMPTS` / `AUTH_LOCKOUT_MINUTES` | Verrouillage temporaire après échecs | `5` / `15` |
| `ARGON2_MEMORY_KIB` / `ARGON2_TIME_COST` / `ARGON2_PARALLELISM` | Paramètres Argon2id (défauts OWASP) | `19456` / `2` / `1` |
| `EMAIL_VERIFICATION_TTL_HOURS` / `PASSWORD_RESET_TTL_MINUTES` | Durée des jetons envoyés par e-mail | `24` / `60` |
| `SMTP_HOST` / `SMTP_PORT` / `EMAIL_FROM` | SMTP (Mailpit en local) | `localhost` / `1025` / `Carlys <no-reply@carlys.local>` |
| `PUBLIC_APP_URL` | Base des liens contenus dans les e-mails | `http://localhost:3000` |

La validation Zod (`src/config/env.schema.ts`) fait échouer le démarrage si une variable requise manque ou est invalide.

### `apps/admin/.env.local`

| Variable | Description | Exemple (factice) |
| --- | --- | --- |
| `NEXT_PUBLIC_API_BASE_URL` | Base de l'API **sans** `/api/v1` — inlinée au build (`NEXT_PUBLIC_*`) | `http://localhost:3000` |

### Mobile — `--dart-define` (pas de fichier `.env`)

| Define | Description | Exemple |
| --- | --- | --- |
| `CARLYS_FLAVOR` | Environnement : `development`, `staging`, `production` | `development` |
| `CARLYS_API_BASE_URL` | Base de l'API | `http://localhost:3000` |

## Lancer les applications

```bash
# API + Admin en parallèle (rechargement à chaud)
pnpm dev

# Ou individuellement
pnpm dev:api      # API NestJS      → http://localhost:3000
pnpm dev:admin    # Admin Next.js   → http://localhost:3001
```

Une fois l'API lancée :

- Swagger : `http://localhost:3000/api/docs` (hors production) ;
- santé : `http://localhost:3000/health` (+ `/health/live`, `/health/ready`) ;
- métriques Prometheus : `http://localhost:3000/metrics`.

L'admin affiche sur sa page d'accueil le **statut de la plateforme** (interrogation de `/health`). La page `/login` est un emplacement documenté : l'authentification admin réelle arrive à l'Étape 7 — aucune fausse authentification n'est simulée.

```bash
# Application mobile (après bootstrap_mobile.sh)
cd apps/mobile
flutter run \
  --dart-define=CARLYS_FLAVOR=development \
  --dart-define=CARLYS_API_BASE_URL=http://localhost:3000
```

> Sur émulateur Android, remplacer `localhost` par `10.0.2.2` pour joindre l'API de la machine hôte.

## Migrations Prisma

Le schéma (`apps/api/prisma/schema.prisma`) est **volontairement vide de modèles** à l'Étape 1 : chaque tranche verticale apporte ses modèles et sa migration.

```bash
pnpm prisma:generate                          # (ré)génère le client Prisma
pnpm prisma:migrate                           # prisma migrate dev (développement)
pnpm prisma:seed                              # seed (données de référence, dès l'Étape 3)
pnpm --filter @carlys/api prisma:studio       # explorateur de données
pnpm --filter @carlys/api prisma:migrate:deploy  # déploiement (staging/production)
```

Règles :

- en développement : `prisma migrate dev` (crée et applique la migration) ;
- en staging/production : `prisma migrate deploy` **avant** la bascule du trafic, **jamais** au démarrage du conteneur ;
- la CI (`api-ci.yml`) exécute `prisma validate` et détecte les migrations manquantes par rapport au schéma.

## Tests

```bash
pnpm test                                # tous les projets TypeScript
pnpm --filter @carlys/api test           # unitaires API (Jest)
pnpm --filter @carlys/api test:e2e       # e2e API (le test /health/live passe sans infra)
pnpm --filter @carlys/api test:cov       # couverture API
pnpm --filter @carlys/admin test         # admin (Vitest + Testing Library)

cd apps/mobile
flutter test                             # tests Flutter
```

## Qualité du code

```bash
pnpm lint             # ESLint 9 (flat config, typescript-eslint strict)
pnpm typecheck        # tsc --noEmit (strict + noUncheckedIndexedAccess)
pnpm format           # Prettier (écriture)
pnpm format:check     # Prettier (vérification)
pnpm check            # format:check + lint + typecheck + test + build
./scripts/check.sh    # équivalent avec build en premier — à lancer avant tout commit

cd apps/mobile
dart format .         # bloquant en CI
flutter analyze
```

## Génération de code Flutter

Riverpod (annotations), Freezed, json_serializable et Drift reposent sur `build_runner` :

```bash
cd apps/mobile
dart run build_runner build --delete-conflicting-outputs
# ou en continu :
dart run build_runner watch --delete-conflicting-outputs
```

## Docker

```bash
docker compose up -d                 # infrastructure seule
docker compose --profile app up      # infrastructure + API + Admin conteneurisées
docker compose down                  # arrêt (ajouter -v pour purger les volumes)
```

| Service | Image | Ports | Rôle |
| --- | --- | --- | --- |
| `postgres` | `postgres:17-alpine` | 5432 | Base de données (init : extension `citext` + base `carlys_test`) |
| `redis` | `redis:7-alpine` | 6379 | Cache, rate limiting |
| `mailpit` | `axllent/mailpit` | 1025 (SMTP), 8025 (UI) | Réception des e-mails de dev |
| `minio` | `minio/minio` | 9000 (S3), 9001 (console) | Stockage compatible S3 |
| `minio-init` | `minio/mc` | — | Crée le bucket `carlys-media` au premier démarrage |
| `api` (profil `app`) | build `apps/api/Dockerfile` | 3000 | API conteneurisée |
| `admin` (profil `app`) | build `apps/admin/Dockerfile` | 3001 | Admin conteneurisé (output standalone) |

Les deux Dockerfiles sont multi-stage avec la **racine du monorepo comme contexte** (nécessaire pour les packages workspace) :

```bash
docker build -f apps/api/Dockerfile -t carlys-api .
docker build -f apps/admin/Dockerfile -t carlys-admin .
```

## Conventions

- **Tranches verticales** : chaque étape livre une fonctionnalité complète de bout en bout (schéma Prisma + API + admin + mobile + tests + docs). Pas de couche « en avance » sans consommateur, pas de dépendance morte.
- **Commits** : [Conventional Commits](https://www.conventionalcommits.org/fr/) — `feat(api): …`, `fix(mobile): …`, `docs: …`, `chore: …`.
- **Branches** : `main` protégée ; travail sur `feat/<sujet>`, `fix/<sujet>`, `docs/<sujet>` ; intégration par pull request avec CI verte.
- **CI GitHub Actions** : `api-ci.yml` (services PostgreSQL + Redis ; format, lint, typecheck, tests, e2e, build, `prisma validate`, détection de migrations manquantes), `admin-ci.yml`, `mobile-ci.yml` (Flutter stable : format bloquant, analyze, test), `security-ci.yml` (TruffleHog + `pnpm audit` niveau high, plus une exécution hebdomadaire).
- **Documentation** : ne documenter que l'existant, ou du planifié explicitement marqué comme tel (« Étape N », « cible »).

## Déploiement

Quatre environnements sont prévus : `development`, `test`, `staging`, `production`. Cibles de production : PostgreSQL et Redis managés, stockage objet S3/R2, images Docker de l'API et de l'admin derrière un reverse proxy Nginx. Les migrations s'exécutent via `prisma migrate deploy` avant la bascule du trafic.

Détails : [infrastructure/deployment/README.md](./infrastructure/deployment/README.md) (ainsi que [nginx](./infrastructure/nginx/README.md) et [monitoring](./infrastructure/monitoring/README.md)).

## Sécurité

Résumé des règles en place à l'Étape 1 :

- aucun secret dans le dépôt — uniquement des `.env.example` factices ; TruffleHog en CI ;
- API durcie : Helmet, CORS liste blanche, rate limiting, validation stricte des entrées (whitelist + `forbidNonWhitelisted`), limite de taille de body (1 Mo), config validée au démarrage ;
- `/metrics` protégé par Bearer token en production ; Swagger désactivé en production ;
- logs structurés Pino avec `requestId` propagé (en-tête `x-request-id`), sans données sensibles ;
- authentification (Étape 2) : mots de passe **Argon2id**, access token JWT court (issuer/audience vérifiés + session contrôlée en base à chaque requête), refresh token **rotatif** stocké hashé (SHA-256) avec **détection de réutilisation** (révocation immédiate de la session), verrouillage temporaire après échecs répétés, réponses anti-énumération, jetons e-mail à usage unique, journal d'audit des événements de sécurité ;
- à venir : OAuth Apple/Google, 2FA (Étape 2+) ; webhooks signés et idempotents (Étape 6).

Politique complète et signalement de vulnérabilités : [SECURITY.md](./SECURITY.md).

## Commandes principales

| Commande | Description |
| --- | --- |
| `pnpm install` | Installe les dépendances du workspace |
| `pnpm dev` | API (3000) + Admin (3001) en parallèle |
| `pnpm dev:api` / `pnpm dev:admin` | Une seule application |
| `pnpm build` | Build de tous les projets (ordre topologique) |
| `pnpm lint` / `pnpm typecheck` | Lint / vérification des types |
| `pnpm test` | Tests de tous les projets TypeScript |
| `pnpm format` / `pnpm format:check` | Prettier |
| `pnpm check` | Toutes les vérifications (avant commit) |
| `pnpm prisma:generate` / `prisma:migrate` / `prisma:seed` | Cycle Prisma |
| `docker compose up -d` / `down` | Infrastructure locale |
| `./scripts/setup.sh` | Installation complète |
| `./scripts/check.sh` | Vérifications complètes (build inclus) |
| `./scripts/bootstrap_mobile.sh` | Prépare l'app Flutter (plateformes + deps) |
| `flutter pub get` | Dépendances Flutter |
| `dart run build_runner build --delete-conflicting-outputs` | Génération de code Flutter |
| `flutter analyze` / `flutter test` | Qualité Flutter |
| `flutter run --dart-define=…` | Lancement mobile |
| `flutter build apk` / `appbundle` / `ios` | Builds de distribution |

## État du projet

**Étape 1 — Fondation : terminée.** Monorepo, API durcie et observable, admin avec statut de plateforme, app Flutter avec design system complet, Docker Compose, scripts, CI, documentation.

**Étape 2 — Authentification : terminée.** Tranche verticale complète : schéma Prisma + migration (User, UserSession, RefreshToken, …), inscription/connexion/refresh rotatif avec détection de réutilisation, verrouillage temporaire, vérification d'e-mail et réinitialisation de mot de passe (Mailpit), gestion des appareils connectés, suppression de compte, audit — et côté Flutter : stockage sécurisé des jetons, renouvellement automatique (single-flight), écrans Connexion/Inscription/Mot de passe oublié/Appareils, routage gardé par l'état de session. Tests unitaires et e2e sur les parcours critiques.

**Étape 3 — Exercices : terminée.** Catalogue relationnel (Exercise, MuscleGroup, Equipment + liaisons rôles primaire/secondaire), **seed de 33 exercices** en français avec 12 groupes musculaires et 10 équipements (`pnpm prisma:seed`, comptes de dev inclus), API `GET /exercises` avec recherche, filtres (groupe musculaire, équipement, difficulté, type) et **pagination par curseur**, fiche détaillée par id ou slug, référentiels `muscle-groups`/`equipment` — le tout servi à travers un **cache Redis tolérant aux pannes** (la base reste la source de vérité si Redis tombe). Côté Flutter : écran bibliothèque (recherche débouncée, puces de filtres, défilement infini), fiche d'exercice complète, nouveaux composants du design system (AppCard, AppSearchField, AppBadge). Tests unitaires, e2e et widgets.

**Étape 4 — Séances offline-first : terminée.** La plus grosse tranche du MVP : base locale **Drift** (séances, séries, file `sync_operations`), chaque écriture part d'abord dans SQLite (aucune série jamais perdue, y compris sans réseau ou après fermeture brutale), puis un **moteur de synchronisation** FIFO strict la rejoue vers l'API (backoff exponentiel 5 s → 5 min, déclencheurs : lancement, retour de connectivité, périodique 3 min, opportuniste). Côté serveur : `WorkoutSession`/`WorkoutSet` avec **UUID générés sur l'appareil** — création, séries (upsert), clôture et abandon **idempotents** (rejouer une requête ne duplique jamais rien), historique paginé par curseur, propriété vérifiée sans fuite d'information. Côté app : écran de **séance active** (saisie des séries avec steppers, types échauffement/normale/dégressive, **minuteur de repos**, durée écoulée, indicateurs de synchronisation), sélecteur d'exercice depuis le catalogue ou libre, reprise de séance depuis l'accueil, **historique** et détail avec volume total. La génération de code (Drift) entre en CI mobile.

**Étape 5 — Progression : terminée.** Les données déjà collectées deviennent lisibles : **records personnels** (charge max, répétitions max, volume max sur une série) recalculés automatiquement à la clôture d'une séance — sans jamais la faire échouer —, **statistiques par période** (semaine/mois/année : séances, séries, volume, durée + volume par intervalle via `date_trunc` whitelisté), **progression par exercice** (meilleure charge et volume à chaque séance) et **mesures corporelles** (poids, masse grasse) à identifiants générés sur l'appareil — création **idempotente** et suppression logique **rejouable**, comme les séances. Côté app : écran **Progression** (sélecteur de période, cartes de synthèse, graphique de volume en barres, records regroupés par exercice, courbe de poids avec ajout/suppression de mesures), accessible depuis l'accueil. Graphiques fl_chart, états erreur/chargement/vide couverts.

**Étape 6 — Abonnements : terminée.** Le premium existe, et c'est le **serveur qui décide** : plans (`free`, `premium`) et correspondances produits par fournisseur en base, webhooks **Stripe** (signature `Stripe-Signature` HMAC vérifiée sur le corps brut, fenêtre anti-rejeu) et **RevenueCat** (Bearer dédié) — tous **idempotents** grâce au journal append-only `SubscriptionEvent` (unicité `(provider, externalEventId)` ; un échec de traitement est journalisé sur l'événement et retraitable par rejeu). Chaque événement projette l'état `Subscription` puis matérialise les **`UserEntitlement`** (accès maintenu jusqu'à la fin de période payée en cas d'impayé/résiliation, expiration réévaluée à chaque lecture, attributions manuelles jamais écrasées). API : `GET /subscriptions/me`, `GET /entitlements` — et le catalogue applique le droit `premium_exercises` : la fiche d'un exercice premium répond 403 sans abonnement. Côté app : écran **Abonnement** (plan effectif, état, droits verrouillés/actifs), écran d'exercice avec état « Exercice Premium » et renvoi vers l'abonnement. Aucun faux paiement : l'achat passera par les stores/Stripe, l'app ne fait qu'afficher l'état serveur.

**Étape 7 — Administration : terminée.** Le back-office devient réel, avec des **comptes administrateurs séparés** des comptes mobiles (Argon2id, jeton JWT à **audience dédiée** `carlys-admin` — jamais interchangeable avec un jeton mobile, dans un sens comme dans l'autre) et un **RBAC par permissions** (`user:read`, `user:update`, `entitlement:grant`, `exercise:publish`, `audit:read`) seedé depuis le code avec les rôles `superadmin`, `support` et `content-manager`. API : synthèse plateforme, liste/fiche des utilisateurs, **suspension** (toutes les sessions révoquées immédiatement, reconnexion refusée), **attribution manuelle d'entitlements** (jamais écrasée par la synchro des webhooks), publication/dépublication d'exercices (cache catalogue invalidé), **journal d'audit** enrichi (acteur, ressource, `requestId`) et paginé. Côté `apps/admin` : connexion réelle, tableau utilisateurs avec recherche, fiche avec actions, journal d'audit — réponses validées par les contrats Zod partagés, le serveur restant seul décideur des accès.

| Étape | Tranche verticale | Contenu principal | Statut |
| --- | --- | --- | --- |
| 1 | Fondation | Monorepo, outillage, sécurité de base, design system, CI | ✅ Terminée |
| 2 | Authentification | JWT access court + refresh rotatif hashé, Argon2id, sessions par appareil, détection de réutilisation | ✅ Terminée |
| 3 | Exercices | Bibliothèque + seed 30+ exercices, cache Redis | ✅ Terminée |
| 4 | Séances | Offline-first Drift + file de synchronisation idempotente | ✅ Terminée |
| 5 | Progression | Records, historique, graphiques | ✅ Terminée |
| 6 | Abonnements | Entitlements côté serveur, RevenueCat possible, Stripe web, webhooks idempotents signés | ✅ Terminée |
| 7 | Administration | Rôles, permissions, audit | ✅ Terminée |

## Documentation

- [`docs/product/`](./docs/product/) — vision produit et fonctionnalités ;
- [`docs/architecture/`](./docs/architecture/) — architecture technique ;
- [`docs/api/`](./docs/api/) — conventions et contrats de l'API ;
- [`docs/database/`](./docs/database/) — base de données et migrations ;
- [`docs/synchronization/`](./docs/synchronization/) — synchronisation offline-first ;
- [`docs/security/`](./docs/security/) — sécurité ;
- [`docs/decisions/`](./docs/decisions/) — décisions d'architecture (ADR) ;
- READMEs locaux : [`apps/api`](./apps/api/README.md), [`apps/admin`](./apps/admin/README.md), [`apps/mobile`](./apps/mobile/README.md), [`infrastructure/docker`](./infrastructure/docker/README.md).
