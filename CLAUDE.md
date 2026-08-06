# CLAUDE.md — Règles de développement Carlys

## Le projet en cinq lignes

Carlys est une plateforme fitness SaaS : application mobile Flutter (offline-first),
API NestJS 11 (monolithe modulaire, Prisma 6 + PostgreSQL 17, Redis) et tableau de bord
admin Next.js 16, organisés en monorepo pnpm (`apps/*`, `packages/*` ; `apps/mobile`
est volontairement hors workspace JS). Le développement avance par **tranches verticales** :
chaque étape livre une fonctionnalité complète (base de données → API → mobile → admin → tests → docs),
jamais une couche horizontale isolée.

| Étape | Contenu | Statut |
| ----- | ------- | ------ |
| 1 | Fondation (monorepo, design system, infra, CI, observabilité) | **Faite** |
| 2 | Authentification (JWT access court + refresh rotatif hashé, Argon2id, sessions par appareil, détection de réutilisation) | À venir |
| 3 | Exercices (catalogue, seed 30+ exercices, cache Redis) | À venir |
| 4 | Séances (offline-first Drift + file de synchronisation idempotente) | À venir |
| 5 | Progression | À venir |
| 6 | Abonnements (entitlements côté serveur, RevenueCat possible, Stripe web, webhooks idempotents signés) | À venir |
| 7 | Administration (rôles, permissions, audit) | À venir |

## Commandes essentielles

Depuis la racine du dépôt :

```bash
pnpm install            # dépendances JS (workspace pnpm)
pnpm dev                # API (3000) + admin (3001) en parallèle
pnpm dev:api            # API seule
pnpm dev:admin          # admin seul
docker compose up -d    # infra locale : postgres, redis, mailpit, minio
docker compose down     # arrêt de l'infra

pnpm prisma:generate    # client Prisma
pnpm prisma:migrate     # prisma migrate dev (apps/api)
pnpm prisma:seed        # seed (apps/api)
```

**Vérification obligatoire avant tout commit** (TypeScript) :

```bash
pnpm build && pnpm format:check && pnpm lint && pnpm typecheck && pnpm test
# ou, équivalent en une commande :
./scripts/check.sh      # (le raccourci `pnpm check` existe aussi)
```

**Flutter** (`apps/mobile`, hors workspace pnpm) :

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Freezed, Riverpod, Drift, json_serializable
flutter analyze         # bloquant, comme en CI
flutter test
flutter run --dart-define=CARLYS_FLAVOR=development --dart-define=CARLYS_API_BASE_URL=http://localhost:3000
```

Les dossiers `android/` et `ios/` ne sont pas versionnés : ils se génèrent via
`./scripts/bootstrap_mobile.sh`. La CI (`.github/workflows/`) rejoue ces mêmes
vérifications : ne pousse jamais un commit qui ne passe pas localement.

## Règles générales (spécification produit — à respecter intégralement)

**Interdits :**

- Ne **jamais** créer une fonctionnalité sans comprendre son domaine.
- Ne **jamais** mettre toute la logique dans un seul fichier.
- Ne **jamais** créer de fichier géant.
- Ne **jamais** dupliquer une logique existante — chercher et réutiliser d'abord.
- Ne **jamais** coder en dur une valeur visuelle (couleur, espacement, rayon, ombre,
  durée d'animation) dans une page Flutter : le design system (`lib/design_system/`)
  est obligatoire.
- Ne **jamais** faire d'appel API directement depuis un widget Flutter — toujours via
  contrôleur → use case → repository.
- Ne **jamais** accéder à Prisma depuis un contrôleur NestJS — l'accès aux données
  passe par les services/repositories du module.
- Ne **jamais** mettre de logique métier dans les contrôleurs HTTP.
- Ne **jamais** commiter un secret dans le dépôt (les `.env.example` ne contiennent
  que des valeurs factices ; TruffleHog tourne en CI).
- Ne **jamais** ignorer une erreur TypeScript ou Dart sans justification écrite.
- Ne **jamais** supprimer un test pour faire passer une fonctionnalité.
- Ne **jamais** inventer une dépendance si une solution standard existe déjà.
- Ne **jamais** ajouter une bibliothèque sans expliquer son utilité.
- Ne **jamais** créer de microservice sans nécessité réelle — l'API est un monolithe
  modulaire.

**Obligations :**

- Toujours privilégier la lisibilité et la maintenabilité.
- Toujours utiliser des types stricts (TS strict + `noUncheckedIndexedAccess` ;
  pas de `any` injustifié, pas de `dynamic` injustifié en Dart).
- Toujours traiter les erreurs (jamais de `catch` vide, jamais d'échec silencieux).
- Toujours valider les entrées (class-validator `whitelist` + `forbidNonWhitelisted`
  côté API ; Zod côté admin et config).
- Toujours écrire les migrations Prisma (jamais de dérive de schéma ; la CI détecte
  les migrations manquantes).
- Toujours mettre à jour la documentation impactée (`docs/`, README concernés).
- Toujours exécuter formatter + lint + analyse + tests après toute modification.

## Tailles de fichiers

Découper proprement (extraction de widgets, services, use cases, modules) dès qu'un
seuil est dépassé — jamais de contournement :

| Type de fichier | Limite |
| --------------- | ------ |
| Widget Flutter | < 250 lignes |
| Service | < 300 lignes |
| Contrôleur | < 200 lignes |
| Use case | < 200 lignes |
| Modèle | ciblé sur une seule responsabilité |
| Module NestJS | un module par domaine métier |

## Qualité exigée par fonctionnalité

Chaque fonctionnalité livrée comprend :

- **Tests** adaptés à sa nature : unitaires (logique), widget (UI Flutter),
  intégration, e2e (API — supertest ; l'e2e `/health/live` passe sans infra).
- **Gestion des états** : erreur, chargement, vide, hors-ligne (composants
  `AppErrorState`, `AppLoadingIndicator`, `AppEmptyState` côté mobile).
- **Accessibilité** : sémantique, contrastes, respect de la réduction d'animations
  système (`AppMotion` la gère déjà).
- **Logs utiles** : Pino structuré côté API, toujours corrélés au `requestId`.
- **Documentation** : Swagger (`/api/docs`, hors production) pour les endpoints,
  `docs/` et README pour l'architecture.

## Conventions spécifiques au dépôt

- **Enveloppes de réponse API** (définies dans `packages/api-contracts`) : succès
  `{ data, meta, requestId }`, erreur `{ error: { code, message, details, requestId } }`.
  Toute nouvelle route les respecte ; versioning URI `/api/v1`.
- **Tokens design** : `packages/design-tokens/src/tokens.json` est la **source de
  vérité** (primaire `#5B5BF6`, accent `#C6F432`, espacements, radius, typo, ombres,
  motion, breakpoints). Toute évolution s'y fait d'abord, puis se répercute dans le
  design system Flutter (`AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`,
  `AppShadows`, `AppMotion`, `AppBreakpoints`) et côté admin.
- **Identifiants** : UUID générables hors ligne (package `uuid` côté mobile) — jamais
  d'identifiant dépendant du serveur pour des entités créées hors connexion.
- **Dates** : stockées et échangées en **UTC** ; l'affichage est localisé côté client.
- **Structure Flutter feature-first** : `lib/features/<feature>/{data,domain,presentation}` —
  règles détaillées dans `apps/mobile/lib/features/README.md`.
- **Structure NestJS** : modules par domaine sous `src/modules/`, pragmatiques
  (contrôleur mince → service → accès données) ; transversal dans `src/common/`,
  config validée par Zod dans `src/config/env.schema.ts` (le serveur refuse de
  démarrer si une variable essentielle manque).
- **Offline-first** (Étape 4) : file de synchronisation idempotente, Drift en local —
  voir `docs/synchronization/offline-first.md`.
- **Entitlements** (Étape 6) : décidés **côté serveur uniquement**, jamais côté client.
- **Pas de faux backend ni de données codées en dur** : les mocks n'existent que
  dans les tests, isolés et remplaçables.
- **Migrations en production** : `prisma migrate deploy` avant bascule du trafic,
  jamais au démarrage du conteneur.
- Ne **jamais** déclarer une fonctionnalité terminée sans avoir réellement exécuté
  ses tests (et les avoir vus passer).

## Check-list de fin de tâche

1. Le code respecte les règles générales et les limites de taille ci-dessus.
2. Aucune valeur visuelle en dur, aucun secret, aucune dépendance injustifiée ajoutée.
3. Migrations Prisma écrites si le schéma a changé.
4. Tests écrits/adaptés et exécutés : `pnpm test` (+ `pnpm --filter @carlys/api test:e2e`
   si l'API est touchée), `flutter test` si le mobile est touché.
5. `./scripts/check.sh` passe (build, format, lint, typecheck, tests) ;
   `flutter analyze && flutter test` passent pour le mobile.
6. Documentation mise à jour (`docs/`, README, Swagger le cas échéant).
7. États erreur/chargement/vide/hors-ligne couverts, accessibilité vérifiée,
   logs corrélés au `requestId`.
