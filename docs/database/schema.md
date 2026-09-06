# Modèle de données cible (PostgreSQL + Prisma)

> **Statut : cible.** Le schéma Prisma actuel (`apps/api/prisma/schema.prisma`) est
> **volontairement vide** à l'Étape 1 : il ne contient que le générateur et la
> datasource PostgreSQL. Les modèles décrits ici arrivent **par tranches
> verticales** (Étapes 2 à 7), chacun avec sa migration, ses tests et son seed.
> Ce document est la référence que chaque tranche vient concrétiser — il ne
> décrit **aucune table existante** aujourd'hui.

Base : PostgreSQL 17 (dev : `postgres:17-alpine` via `docker-compose.yml`),
accédée exclusivement via Prisma 6 depuis `apps/api`. L'extension `citext` et la
base `carlys_test` sont créées par `infrastructure/database/init/01-init.sql`.
Les migrations s'appliquent via `prisma migrate deploy` **avant** la bascule du
trafic, jamais au démarrage du conteneur ; la CI (`api-ci.yml`) échoue si une
migration manque par rapport au schéma.

## Domaines et tranches verticales

| Domaine | Modèles | Tranche |
|---|---|---|
| Identité | `User`, `UserProfile`, `UserCredential`, `UserSession`, `RefreshToken`, `EmailVerification`, `PasswordReset`, `ExternalIdentity` — **implémenté** (migration `20260806180000_auth_foundation`) ; `UserDevice` et `UserPreference` différés | Étape 2 ✅ |
| Catalogue d'exercices | `Exercise`, `ExerciseMuscle`, `ExerciseEquipment`, `MuscleGroup`, `Equipment` — **implémenté** (migration `20260806220000_exercise_catalog`, contenu français directement sur `Exercise`) ; `ExerciseTranslation`, `ExerciseMedia`, `ExerciseVariant`, `CustomExercise` différés | Étape 3 ✅ |
| Médias | `MediaAsset` | Étape 3 (premier besoin : médias d'exercices) |
| Programmes | `WorkoutTemplate`, `WorkoutTemplateExercise`, `WorkoutTemplateSet`, `WorkoutSessionPlanItem` — **implémenté** (migrations `20260808135805_workout_templates` et `20260808153828_workout_session_plan_items` ; modèles de séance autonomes, plan de séance persisté pour la reprise multi-appareil, ids générés sur l'appareil) ; `TrainingProgram`, `ProgramWeek`, `ProgramDay` (programmes multi-semaines) différés | Étape 4 ✅ |
| Séances | `WorkoutSession`, `WorkoutSet` — **implémenté** (migration `20260807010000_workout_sessions`, ids générés sur l'appareil, écritures idempotentes ; provenance et cibles ajoutées par `20260808135805_workout_templates`) ; `WorkoutSessionExercise` fusionné dans `WorkoutSet` (`exerciseId` + `exerciseName` dénormalisé), `WorkoutNote` porté par `WorkoutSession.notes`, `PersonalRecord` livré à l'Étape 5 | Étape 4 ✅ |
| Progression | `PersonalRecord`, `BodyMetric` — **implémenté** (migration `20260807040000_progress`, records recalculés à la clôture, mesures idempotentes) ; `ProgressGoal` et `ProgressSnapshot` différés (agrégats calculés à la volée) | Étape 5 ✅ |
| Abonnements | `SubscriptionPlan`, `SubscriptionProduct`, `Subscription`, `SubscriptionEvent`, `UserEntitlement` — **implémenté** (migration `20260807064832_subscriptions`, conforme à la cible) | Étape 6 ✅ |
| Notifications | `Notification`, `NotificationPreference`, `PushDevice` | Introduit avec l'intégration FCM réelle (au plus tôt Étape 4, `NotificationPreference` au plus tard Étape 6) |
| Administration | `AdminUser`, `AdminRole`, `AdminPermission` (+ jointures), `AuditLog` enrichi (`actorType`, `resourceType`/`resourceId`, `requestId`) — **implémenté** (migration `20260807070624_administration` ; `AuditLog` introduit dès l'Étape 2) | Étape 7 ✅ |
| Communauté | `Friendship`, `Encouragement`, `CommunityChallenge`, `ChallengeParticipation`, `CommunityPreference`, `QuizAnswer`, `CommunityBlock`, `CommunityReport` — **implémenté** (migrations `20260811120000_community`, `20260811190000_quiz_answers`, `20260830120000_friend_codes`, `20260906100000_community_moderation`, `20260906110000_community_monthly_challenges`, `20260906130000_community_report_snapshot`) — voir la section [Communauté](#communauté-implémenté) | Vague 1 ✅ |

## Conventions transverses

Ces règles s'appliquent à **tous** les modèles ci-dessous ; elles ne sont pas
répétées modèle par modèle.

- **Identifiants** : UUID partout (clé primaire `id`). Côté serveur,
  `gen_random_uuid()` (natif PostgreSQL). Côté mobile, les entités de séance
  (`WorkoutSession`, `WorkoutSessionExercise`, `WorkoutSet`, `WorkoutNote`) sont
  créées **hors ligne** avec un UUID généré par le client (paquet `uuid`
  Flutter) : l'API accepte l'identifiant fourni, ce qui rend la synchronisation
  rejouable.
- **Dates** : `timestamptz` uniquement, toujours en UTC. Nommage `*At`
  (`createdAt`, `expiresAt`, `measuredAt`…). L'affichage local est l'affaire des
  clients.
- **Horodatage systématique** : `createdAt` (défaut `now()`) et `updatedAt`
  (`@updatedAt`) sur chaque modèle, sauf tables strictement append-only
  (`AuditLog`, `SubscriptionEvent`) qui n'ont que `createdAt`.
- **Suppression logique** : `deletedAt` nullable quand l'historique doit
  survivre à la suppression (`User`, `Exercise`, `CustomExercise`,
  `TrainingProgram`, `WorkoutTemplate`, `MediaAsset`). Les contraintes
  d'unicité concernées deviennent des **index uniques partiels**
  (`WHERE deleted_at IS NULL`). Les tables de jetons (`EmailVerification`,
  `PasswordReset`, `UserSession` expirées) sont purgées physiquement.
- **E-mail** : type `citext` (unicité insensible à la casse), extension
  installée par `01-init.sql`.
- **Nommage physique** : modèles Prisma en PascalCase, tables et colonnes en
  `snake_case` via `@@map`/`@map`. Énumérations métier en `enum` Prisma
  (enums PostgreSQL natifs).
- **Pagination par curseur** : toutes les listes API sont paginées par curseur
  (`DEFAULT_PAGE_SIZE = 20`, `MAX_PAGE_SIZE = 100`,
  `packages/shared-config`). Chaque liste s'appuie sur un index composite
  couvrant l'ordre de tri, se terminant par `id` pour départager les
  ex-aequo — ex. `(user_id, started_at DESC, id)` sur `workout_sessions`.
- **Transactions** : toute opération multi-tables critique est exécutée en
  transaction Prisma — rotation de refresh token, ingestion d'une séance
  (session + exercices + séries + records personnels), traitement d'un webhook
  d'abonnement (événement + abonnement + entitlements).
- **Champs JSON** : réservés aux métadonnées de systèmes externes, aux payloads
  bruts de webhooks et aux configurations réellement variables. **Jamais** pour
  remplacer une relation ou une colonne interrogeable.
- **Contraintes et index attendus** (exemples structurants) :

| Contrainte | Où | Pourquoi |
|---|---|---|
| `UNIQUE (email)` partiel (`citext`) | `users`, `admin_users` | un compte actif par adresse |
| `UNIQUE (idempotency_key)` | `workout_sessions` | une écriture de séance rejouée n'est appliquée qu'une fois |
| `UNIQUE (provider, external_event_id)` | `subscription_events` | un événement webhook traité une seule fois |
| `UNIQUE (provider, provider_user_id)` | `external_identities` | une identité OAuth liée à un seul compte |
| `UNIQUE (exercise_id, locale)` | `exercise_translations` | une traduction par langue |
| `UNIQUE (user_id, exercise_id, record_type)` | `personal_records` | un record courant par type |
| `UNIQUE (token)` (FCM) | `push_devices` | un jeton push enregistré une seule fois |

---

## Identité — Étape 2 (implémenté)

Cœur de l'authentification : JWT d'accès courts, refresh tokens **rotatifs et
hashés**, mots de passe **Argon2id**, sessions par appareil, détection de
réutilisation d'un refresh token déjà consommé.

> Implémenté dans `apps/api/prisma/schema.prisma` (migration
> `20260806180000_auth_foundation`). Deux ajustements par rapport à la cible
> initiale : la chaîne de rotation est portée par le couple
> `UserSession` + `RefreshToken` (une ligne par jeton, statuts
> `ACTIVE | ROTATED | REVOKED`) plutôt que par un `familyId` ; et `UserDevice`
> est différé — les métadonnées d'appareil vivent sur `UserSession` jusqu'à
> l'arrivée des notifications push.

### `User`
Racine de l'identité d'un membre (application mobile). Aucune donnée sensible
d'authentification ici.
- Champs clés : `id`, `email` (`citext`, unique partiel), `status`
  (`active | suspended | deleted`), `emailVerifiedAt`, `deletedAt`.
- Relations : 1–1 `UserProfile`, `UserCredential`, `UserPreference` ; 1–n
  `UserSession`, `UserDevice`, `ExternalIdentity`, `EmailVerification`,
  `PasswordReset`, et vers tous les domaines métier (séances, mesures,
  abonnements…).

### `UserProfile`
Données de présentation et de contexte, séparées de l'identité pour garder
`User` minimal.
- Champs clés : `userId` (unique), `displayName`, `avatarMediaId` (→
  `MediaAsset`, nullable), `birthDate`, `heightCm`, `unitSystem`
  (`metric | imperial`), `locale`, `timezone`.
- Profil métabolique (migration `20260807171346_nutrition_profile`) : `sex`
  (`MALE | FEMALE`, nullable), `activityLevel` (`SEDENTARY → VERY_ACTIVE`,
  nullable), `nutritionGoal` (`LOSE_WEIGHT | MAINTAIN | GAIN_MUSCLE`,
  nullable) — consommés par `GET /nutrition/metabolism` ; le poids n'est
  **pas** stocké ici, il provient de la dernière `BodyMetric` `WEIGHT_KG`.
- Relations : 1–1 `User` ; n–1 `MediaAsset` (avatar).

### `UserCredential`
Secret de connexion, isolé dans sa propre table pour restreindre les chemins de
lecture.
- Champs clés : `userId` (unique), `passwordHash` (**Argon2id**, jamais exposé
  par l'API), `passwordUpdatedAt`.
- Relations : 1–1 `User`. Nullable côté usage : un compte purement OAuth n'a pas
  de ligne ici.

### `UserSession` (implémenté)
Une session **par appareil**. L'access token JWT référence la session (claim
`sid`) : le guard vérifie son état en base à chaque requête, la révoquer
invalide donc immédiatement ses access tokens.
- Champs clés : `userId`, `deviceName`, `devicePlatform`, `ipAddress`,
  `userAgent`, `expiresAt` (expiration **glissante**, repoussée à chaque
  rotation), `lastUsedAt`, `revokedAt`, `revokedReason`
  (`logout | user_revoked | user_revoked_all | password_reset |
  password_changed | refresh_reuse_detected | account_deleted`).
- Relations : n–1 `User` ; 1–n `RefreshToken`.
- Index : `(user_id)`.

### `RefreshToken` (implémenté)
Un jeton opaque par rotation — **jamais stocké en clair**, uniquement son hash
SHA-256 (`tokenHash` unique).
- Champs clés : `sessionId`, `tokenHash` (unique), `status`
  (`ACTIVE | ROTATED | REVOKED`), `expiresAt`, `rotatedAt`.
- Rotation **conditionnelle** en transaction : seul un jeton encore `ACTIVE`
  peut être rotaté ; deux refresh concurrents du même jeton → le second est
  traité comme une réutilisation.
- Détection de réutilisation : présenter un jeton `ROTATED`/`REVOKED` →
  révocation de **toute la session** + événement d'audit.
- Index : `(session_id)`.

### `UserDevice` (différé — arrivera avec les notifications push)
Appareil logique de l'utilisateur (un téléphone = un appareil), support des
sessions et du push.
- Champs clés : `userId`, `platform` (`ios | android`), `model`, `osVersion`,
  `appVersion`, `lastSeenAt`.
- Relations : n–1 `User` ; 1–n `UserSession` ; 1–n `PushDevice` (quand FCM
  arrive).

### `EmailVerification`
Jeton de vérification d'adresse, à usage unique, stocké hashé.
- Champs clés : `userId`, `tokenHash` (unique), `expiresAt`, `consumedAt`.
- Relations : n–1 `User`. Purge physique après expiration/consommation.

### `PasswordReset`
Jeton de réinitialisation de mot de passe — mêmes règles que
`EmailVerification` (hashé, usage unique, expirant, purgé).
- Champs clés : `userId`, `tokenHash` (unique), `expiresAt`, `consumedAt`,
  `requestIp`.
- Relations : n–1 `User`.

### `ExternalIdentity`
Lien vers un fournisseur d'identité externe (Sign in with Apple, Google), si/
quand activé.
- Champs clés : `userId`, `provider`, `providerUserId`
  (unique composé `(provider, providerUserId)`), `email` rapporté par le
  fournisseur, `lastAuthenticatedAt`.
- Relations : n–1 `User` (un utilisateur peut lier plusieurs fournisseurs).

### `UserPreference`
Préférences applicatives transverses, une ligne par utilisateur, **colonnes
explicites** (pas de sac JSON) : chaque nouvelle préférence est une migration.
- Champs clés : `userId` (unique), unités d'affichage, premier jour de la
  semaine, préférences de confidentialité, opt-in e-mails produit.
- Relations : 1–1 `User`. Les préférences de **notification** par canal vivent
  dans `NotificationPreference` (domaine Notifications).

---

## Catalogue d'exercices — Étape 3 (implémenté)

> Implémenté (migration `20260806220000_exercise_catalog`, seed
> `pnpm prisma:seed` : 170 exercices, 12 groupes musculaires, 15 équipements, et les photos du catalogue déposées dans le stockage objet).
>
> `Exercise.deletedAt` porte la suppression DOUCE venue de l'administration :
> l'exercice quitte le catalogue (et `isPublished` tombe avec lui), mais les
> séries déjà réalisées, les records et les modèles qui le citent restent
> intacts. `POST /admin/exercises/:id/restore` le remet, dépublié.
> Ajustements par rapport à la cible : le contenu (nom, description,
> instructions) vit en français directement sur `Exercise` —
> `ExerciseTranslation` arrivera avec l'i18n ; `ExerciseMedia`,
> `ExerciseVariant` et `CustomExercise` sont différés (médias avec le module
> `media`, exercices personnalisés avec le créateur de programme). Les
> équipements passent par la table de liaison `ExerciseEquipment`, et
> `ExerciseMuscle` porte un rôle `PRIMARY | SECONDARY` (exactement un
> `PRIMARY` par exercice, garanti par le seed et la couche application).

Catalogue officiel (seed ≥ 30 exercices, `pnpm prisma:seed`), multilingue,
servi avec cache Redis (lecture intensive, écriture rare — invalidation à la
publication).

### `Exercise`
Exercice du catalogue officiel, entité neutre en langue (le contenu textuel est
dans `ExerciseTranslation`).
- Champs clés : `id`, `slug` (unique, stable pour le cache et les URLs),
  `measurementType` (`reps | duration | distance` — pilote les champs de série
  autorisés), `level` (`beginner | intermediate | advanced`), `mechanics`
  (`compound | isolation`), `force` (`push | pull | static`), `isPublished`,
  `deletedAt`.
- Relations : 1–n `ExerciseTranslation`, `ExerciseMedia`, `ExerciseMuscle`,
  `ExerciseVariant` ; n–n `Equipment` (table de jointure) ; référencé par les
  programmes, les séances et les records.

### `ExerciseTranslation`
Contenu localisé d'un exercice.
- Champs clés : `exerciseId`, `locale`, `name`, `shortDescription`,
  `instructions` (étapes ordonnées). Unique `(exerciseId, locale)`.
- Relations : n–1 `Exercise`.
- Index de recherche sur `name` (préfixe/trigram) pour la recherche du
  catalogue.

### `ExerciseMedia`
Association ordonnée entre un exercice et ses médias.
- Champs clés : `exerciseId`, `mediaAssetId`, `role`
  (`thumbnail | video | illustration`), `position`.
  Unique `(exerciseId, role, position)`.
- Relations : n–1 `Exercise`, n–1 `MediaAsset`.

### `MuscleGroup`
Référentiel des groupes musculaires (seedé, quasi immuable).
- Champs clés : `slug` (unique), nom localisable, zone corporelle.
- Relations : 1–n `ExerciseMuscle`.

### `ExerciseMuscle`
Jointure exercice ↔ groupe musculaire, qualifiée.
- Champs clés : `exerciseId`, `muscleGroupId`, `role`
  (`primary | secondary`). Unique `(exerciseId, muscleGroupId)`.
- Relations : n–1 `Exercise`, n–1 `MuscleGroup`.

### `Equipment`
Référentiel du matériel (barre, haltères, poids du corps…), seedé.
- Champs clés : `slug` (unique), nom localisable.
- Relations : n–n `Exercise`.

### `ExerciseVariant`
Lien orienté entre deux exercices du catalogue (« variante de » : inclinaison,
prise, unilatéral…).
- Champs clés : `exerciseId`, `variantExerciseId`, `variationType`.
  Unique `(exerciseId, variantExerciseId)` ; contrainte `CHECK` interdisant
  l'auto-référence.
- Relations : n–1 `Exercise` (deux fois).

### `CustomExercise`
Exercice créé par un utilisateur, **privé** (jamais visible d'un autre compte),
hors cache catalogue.
- Champs clés : `id`, `ownerId` (→ `User`), `name`, `measurementType`,
  matériel/muscles optionnels, `deletedAt` (une suppression ne casse pas
  l'historique des séances qui l'utilisent).
- Relations : n–1 `User` ; référencé par les lignes de programme et de séance
  **en exclusion mutuelle** avec `Exercise` (voir `WorkoutTemplateExercise`).
- Index : `(owner_id, name)`.

---

## Médias — Étape 3

### `MediaAsset`
Représentation en base d'un objet stocké dans S3/R2 en production (dev : MinIO,
bucket `carlys-media` créé par le service `minio-init` du compose). La base ne
stocke **jamais** le binaire.
- Champs clés : `id`, `storageKey` (unique, chemin objet), `mimeType`,
  `sizeBytes`, `checksum`, `width`/`height`/`durationSeconds` (selon type),
  `status` (`pending | ready | failed` — upload en deux temps), `ownerId`
  nullable (null = média du catalogue, sinon média utilisateur), `deletedAt`.
- Relations : n–1 `User` (optionnelle) ; référencé par `ExerciseMedia` et
  `UserProfile.avatarMediaId`.

---

## Programmes — Étape 4

Structures **prescriptives** (ce qui est prévu), distinctes des séances
**réalisées**. Un programme peut être officiel (owner null, géré à l'Étape 7
par l'admin) ou personnel.

### `TrainingProgram`
Programme d'entraînement sur plusieurs semaines.
- Champs clés : `id`, `ownerId` nullable, `name`, `goal`, `level`,
  `weekCount`, `isPublished` (programmes officiels), `deletedAt`.
- Relations : 1–n `ProgramWeek` ; n–1 `User` (optionnelle).

### `ProgramWeek`
Semaine ordonnée d'un programme.
- Champs clés : `programId`, `position`. Unique `(programId, position)`.
- Relations : n–1 `TrainingProgram` ; 1–n `ProgramDay`.

### `ProgramDay`
Jour d'une semaine : repos, ou renvoi vers un modèle de séance.
- Champs clés : `weekId`, `position`, `isRestDay`, `workoutTemplateId`
  nullable. Unique `(weekId, position)` ; `CHECK` : jour de repos ⇔ pas de
  template.
- Relations : n–1 `ProgramWeek` ; n–1 `WorkoutTemplate` (optionnelle).

### `WorkoutTemplate` — implémenté

> Implémenté (migration `20260808135805_workout_templates`). Contrat détaillé :
> [`docs/product/workout-templates.md`](../product/workout-templates.md).
> Écarts assumés par rapport à la cible ci-dessus, tous rattrapables par des
> colonnes nullables plus tard :
>
> - **D10** — `userId` est **non nul** (pas `ownerId` nullable) : aucun modèle
>   officiel n'est produit aujourd'hui, et un champ nullable obligerait chaque
>   requête à gérer un cas inexistant.
> - **D8** — une seule mesure prévue, **répétitions × charge** :
>   `targetDurationSeconds`, `targetDistanceMeters`, `targetRpe`, `tempo`,
>   `targetPercentOf1Rm` et `supersetGroup` sont hors périmètre.
> - `CustomExercise` n'existe pas : un exercice hors catalogue est une ligne à
>   `exerciseId` nul portée par son seul `exerciseName` dénormalisé.

Modèle de séance réutilisable — document **prescriptif**, autonome (les
programmes multi-semaines restent différés).
- Champs clés : `id` (**UUID généré par le client**, hors ligne), `userId`,
  `name`, `notes`, `estimatedDurationMinutes` (saisie utilisateur, jamais
  calculée), `lastUsedAt` (daté par le serveur au lancement d'une séance),
  `deletedAt` (suppression **logique** — les séances passées n'y perdent rien).
- Relations : n–1 `User` (`onDelete: Cascade`) ; 1–n
  `WorkoutTemplateExercise` ; référencé par `WorkoutSession.templateId`.
- Index : `(userId, updatedAt DESC)` (liste paginée par curseur).
- **Pas d'unicité sur `name`** : un appareil hors ligne ne peut pas vérifier
  une unicité globale, et la vérifier au serveur transformerait une création
  hors ligne acquittée en travail perdu.

### `WorkoutTemplateExercise` — implémenté
Ligne d'exercice prescrite dans un modèle, ordonnée.
- Champs clés : `id` (UUID client), `templateId`, `exerciseId` nullable,
  `exerciseName` **dénormalisé** (le modèle survit au catalogue), `position`,
  `notes`. Unique `(templateId, position)`.
- Relations : n–1 `WorkoutTemplate` (`onDelete: Cascade`) ; n–1 `Exercise`
  (`onDelete: SetNull`) ; 1–n `WorkoutTemplateSet`.
- `position` est **dérivée de l'ordre du tableau reçu**, jamais transmise :
  un client ne peut produire ni trou ni doublon. L'unicité tient parce que le
  contenu est toujours réécrit intégralement dans une transaction.

### `WorkoutTemplateSet` — implémenté
Série **prévue** d'une ligne de modèle : des cibles, pas des mesures.
- Champs clés : `id` (UUID client), `templateExerciseId`, `position`, `kind`
  (`WorkoutSetKind` réutilisé : `WARMUP | NORMAL | DROP`), `targetReps`,
  `targetWeightKg` (`decimal(6,2)`), `restSeconds`.
  Unique `(templateExerciseId, position)`.
- Relations : n–1 `WorkoutTemplateExercise` (`onDelete: Cascade`).
- Les trois cibles sont **facultatives** : un modèle « 4 × 8 » sans charge
  prévue est légitime (poids du corps, charge décidée le jour même).

Le **contenu** d'un modèle (lignes et séries prévues) est supprimé
**physiquement** à chaque enregistrement et à chaque suppression du modèle : ce
n'est pas de l'historique, rien ne le référence. Seul `WorkoutTemplate` porte un
`deletedAt`.

---

## Séances — Étape 4 (implémenté)

> Implémenté (migration `20260807010000_workout_sessions`). Ajustements par
> rapport à la cible : `WorkoutSessionExercise` est fusionné dans `WorkoutSet`
> (chaque série porte `exerciseId` nullable + `exerciseName` dénormalisé — le
> regroupement par exercice se fait à l'affichage) ; les notes vivent sur
> `WorkoutSession.notes` ; `PersonalRecord` est livré à l'Étape 5 (voir la
> section Progression). Les ids sont
> des **UUID générés sur l'appareil** et toutes les écritures sont rejouables
> (voir `docs/synchronization/offline-first.md`).
>
> La migration `20260808135805_workout_templates` ajoute quatre colonnes
> **nullables sans valeur par défaut** (donc non bloquantes, aucune ligne
> réécrite) : `WorkoutSession.templateId` / `templateName` et
> `WorkoutSet.plannedReps` / `plannedWeightKg`.

Séances **réalisées**, écrites offline-first : le mobile journalise dans Drift
et rejoue une file de synchronisation **idempotente** vers l'API. Toute
l'ingestion (session + exercices + séries + notes + recalcul des records) est
transactionnelle.

### `WorkoutSession`
Une séance effectuée (ou en cours) par un utilisateur.
- **Provenance (implémenté)** : `templateId` nullable (FK
  `onDelete: SetNull` — une purge physique du modèle n'efface jamais la
  séance) et `templateName` **dénormalisé, immuable** : le nom du modèle *au
  moment du lancement*. `name` reste le titre modifiable de la séance ;
  renommer la séance ne falsifie pas son origine. Index `(templateId)`.
- Champs clés : `id` (**UUID généré par le client**, hors ligne),
  `idempotencyKey` (**unique** — un rejeu de la file de synchronisation ne crée
  jamais de doublon), `userId`, `templateId` nullable (origine), `startedAt`,
  `endedAt` nullable, `status` (`in_progress | completed | abandoned`),
  `timezone` (contexte local de réalisation), `deletedAt`.
- Relations : n–1 `User` ; n–1 `WorkoutTemplate` (optionnelle) ; 1–n
  `WorkoutSessionExercise`, `WorkoutNote`, `WorkoutSessionPlanItem`.
- Index : `(user_id, started_at DESC, id)` (historique paginé par curseur).

### `WorkoutSessionPlanItem` — implémenté
Série **prévue** d'une séance : copie APLATIE du modèle au moment du lancement
(migration `20260808153828_workout_session_plan_items`).
- Raison d'être : rendre la reprise **multi-appareil** possible. Sans elle, un
  téléphone qui reprend une séance commencée ailleurs voit les séries faites
  mais plus aucune cible.
- Champs clés : `id` (UUID client), `sessionId`, `exercisePosition`,
  `exerciseId` nullable, `exerciseName` **dénormalisé**, `setPosition`, `kind`,
  `targetReps`, `targetWeightKg` (`decimal(6,2)`), `restSeconds`, `doneSetId`
  nullable, `skipped`. Unique `(sessionId, exercisePosition, setPosition)`.
- Relations : n–1 `WorkoutSession` (`onDelete: Cascade`) ; n–1 `Exercise`
  (`onDelete: SetNull`).
- `doneSetId` est **volontairement sans clé étrangère** : hors ligne, la série
  peut encore être dans la file d'envoi de l'appareil quand l'appariement
  remonte. Une contrainte ferait échouer l'opération en 4xx, donc la perdrait ;
  un identifiant orphelin est sans conséquence.
- C'est une **copie**, pas un lien vivant : renommer ou supprimer le modèle
  ensuite ne touche jamais une séance déjà lancée (D1 de
  [workout-templates.md](../product/workout-templates.md)).

### `WorkoutSessionExercise`
Exercice effectué au sein d'une séance, ordonné, groupable en supersets/
circuits.
- Champs clés : `id` (UUID client), `sessionId`, `position`, `exerciseId`
  **ou** `customExerciseId` (exclusion mutuelle), `supersetGroup` (nullable —
  même sémantique que dans les templates), `notes`.
  Unique `(sessionId, position)`.
- Relations : n–1 `WorkoutSession` ; n–1 `Exercise` / `CustomExercise` ; 1–n
  `WorkoutSet`.

### `WorkoutSet`
Série réalisée — la donnée la plus volumineuse de la plateforme.
- **Cible du moment (implémenté)** : `plannedReps` et `plannedWeightKg`
  (`decimal(6,2)`) figent ce qui était **affiché** quand l'utilisateur a validé
  la série, null hors modèle. C'est ce qui permet à l'historique de dire
  « prévu 8 × 60 kg, fait 7 × 60 kg » des mois plus tard, même modèle supprimé.
  Fait historique : `PATCH /workout-sets/:id` ne les accepte pas.
- Champs clés : `id` (UUID client), `sessionExerciseId`, `position`, `setType`
  (`warmup | normal | dropset`), mesures selon le type d'exercice : `reps` +
  `weightKg` (décimal), ou `durationSeconds`, ou `distanceMeters` ; ressenti :
  `rpe` (0–10, décimal) et/ou `rir` (entier) ; `tempo`, `restSeconds`,
  `completedAt`, `isCompleted`.
  Unique `(sessionExerciseId, position)`.
- Relations : n–1 `WorkoutSessionExercise` ; référencée par `PersonalRecord`.

### `WorkoutNote`
Note libre horodatée attachée à une séance (ressenti global, douleur,
matériel indisponible…).
- Champs clés : `id` (UUID client), `sessionId`, `body`, `createdAt`.
- Relations : n–1 `WorkoutSession`.

### `PersonalRecord`
Record personnel **courant** par utilisateur × exercice × type de record,
recalculé en transaction lors de l'ingestion d'une séance.
- Champs clés : `userId`, `exerciseId` (ou `customExerciseId`, exclusion
  mutuelle), `recordType`
  (`max_weight | max_reps | estimated_1rm | max_duration | max_distance`),
  `value` (décimal), `achievedAt`, `workoutSetId` (→ série d'origine, preuve).
  Unique `(userId, exerciseId, recordType)`.
- Relations : n–1 `User`, `Exercise`/`CustomExercise`, `WorkoutSet`.

---

## Progression — Étape 5 (implémenté)

> Implémenté (migration `20260807040000_progress`). Ajustements par rapport à
> la cible : `PersonalRecord` est rangé dans ce domaine et sa clé unique est
> `(userId, exerciseName, recordType)` — le nom dénormalisé couvre aussi les
> exercices saisis librement ; `exerciseId` et `sessionId` restent des liens
> optionnels (`SET NULL`). Les types de record livrés sont
> `MAX_WEIGHT | MAX_REPS | MAX_SET_VOLUME` (le 1RM estimé et les records de
> durée/distance viendront avec les besoins réels). Le recalcul a lieu à la
> **clôture** de la séance et ne peut jamais la faire échouer (erreur
> journalisée, rattrapage à la séance suivante). `BodyMetric` est livré avec
> `metricType` (`WEIGHT_KG | BODY_FAT_PERCENT`) et sans colonne `unit` (tout
> est stocké en unités métriques). `ProgressGoal` et `ProgressSnapshot` sont
> **différés** : les agrégats (totaux et volume par intervalle `date_trunc`
> whitelisté) se calculent à la volée sur les index existants, largement
> suffisant à cette échelle.

### `BodyMetric`
Mesure corporelle horodatée saisie par l'utilisateur.
- Champs clés : `id` (UUID client possible — saisie hors ligne), `userId`,
  `metricType` (`weight | body_fat | waist | chest | …`), `value` (décimal),
  `unit` (normalisée au système métrique en base), `measuredAt`, `deletedAt`.
- Relations : n–1 `User`.
- Index : `(user_id, metric_type, measured_at DESC)` (courbes fl_chart).

### `ProgressGoal`
Objectif déclaré : poids corporel cible, performance cible sur un exercice,
fréquence d'entraînement.
- Champs clés : `userId`, `goalType`, `exerciseId` nullable (objectifs de
  performance), `targetValue`, `startValue`, `deadline` nullable, `status`
  (`active | achieved | abandoned`), `achievedAt`.
- Relations : n–1 `User` ; n–1 `Exercise` (optionnelle).

### `ProgressSnapshot`
Agrégat périodique **précalculé** (volume total, tonnage, nombre de séances,
répartition musculaire) pour servir les graphiques sans re-agréger les
`WorkoutSet` à chaque lecture.
- Champs clés : `userId`, `period` (`week | month`), `periodStart` (date),
  agrégats en colonnes numériques dédiées.
  Unique `(userId, period, periodStart)`.
- Relations : n–1 `User`. Recalculable à tout moment depuis les séances (donnée
  dérivée, jamais source de vérité).

---

## Abonnements — Étape 6 (implémenté)

> Implémenté (migration `20260807064832_subscriptions`), conforme à la cible.
> Précisions : `UserEntitlement.entitlementKey` est une chaîne (les clés
> réservées vivent dans `packages/api-contracts` — le code est la source de
> vérité) ; `SubscriptionEvent.subscriptionId` est nullable et détaché
> (`SET NULL`) si l'abonnement disparaît, le journal restant append-only ;
> l'accès est maintenu jusqu'à la fin de la période payée pour
> `PAST_DUE`/`CANCELED`, et les attributions manuelles (Étape 7) ne sont
> jamais écrasées par la synchronisation des webhooks.

Les droits (**entitlements**) sont évalués **côté serveur** — jamais déduits
par le client. Fournisseurs : Stripe (web), RevenueCat possible pour les stores
mobiles. Tous les webhooks sont **signés** (signature vérifiée avant tout
traitement) et **idempotents**.

### `SubscriptionPlan`
Plan commercial interne (ex. `free`, `premium`), indépendant des fournisseurs
de paiement.
- Champs clés : `slug` (unique), `name`, `isActive`.
- Relations : 1–n `SubscriptionProduct`, `Subscription`.

### `SubscriptionProduct`
Correspondance entre un plan interne et un produit chez un fournisseur.
- Champs clés : `planId`, `provider` (`stripe | revenuecat | app_store |
  play_store`), `externalProductId`, `billingPeriod` (`monthly | yearly`).
  Unique `(provider, externalProductId)`.
- Relations : n–1 `SubscriptionPlan`.

### `Subscription`
État courant de l'abonnement d'un utilisateur, projeté depuis les événements
fournisseurs.
- Champs clés : `userId`, `planId`, `provider`, `externalSubscriptionId`
  (unique `(provider, externalSubscriptionId)`), `status`
  (`trialing | active | past_due | canceled | expired`),
  `currentPeriodStart`, `currentPeriodEnd`, `cancelAtPeriodEnd`, `trialEndsAt`,
  `externalCustomerId` nullable (client chez le fournisseur, Stripe `cus_…`,
  appris par webhook — migration `20260906120000_subscription_stripe_customer` :
  réutilisé au prochain paiement et requis par le portail de gestion
  `POST /subscriptions/portal`).
- Relations : n–1 `User`, n–1 `SubscriptionPlan` ; 1–n `SubscriptionEvent`.
- Index : `(user_id, status)`.

### `SubscriptionEvent`
Journal **append-only** des webhooks reçus — la garantie d'idempotence du
domaine.
- Champs clés : `provider`, `externalEventId` (**unique
  `(provider, externalEventId)` : un événement n'est traité qu'une seule
  fois** — l'insertion en conflit court-circuite le retraitement), `eventType`,
  `payload` (JSON brut du webhook — usage légitime du JSON), `receivedAt`,
  `processedAt` nullable, `processingError` nullable.
- Relations : n–1 `Subscription` (nullable tant que la corrélation n'est pas
  établie).
- Traitement en transaction : insertion de l'événement → mise à jour de
  `Subscription` → recalcul des `UserEntitlement`.

### `UserEntitlement`
Source de vérité **serveur** des droits effectifs d'un utilisateur, matérialisée
pour une lecture O(1) par l'API et le mobile.
- Champs clés : `userId`, `entitlementKey` (ex. `premium`), `isActive`,
  `expiresAt` nullable, `sourceSubscriptionId` nullable (un entitlement peut
  aussi être accordé manuellement — Étape 7, tracé dans `AuditLog`).
  Unique `(userId, entitlementKey)`.
- Relations : n–1 `User` ; n–1 `Subscription` (optionnelle).

---

## Notifications — avec l'intégration FCM (config réelle, pas de dépendance morte)

FCM et sa configuration arrivent ensemble (au plus tôt Étape 4 pour les rappels
de séance) ; `NotificationPreference` est requis au plus tard à l'Étape 6
(communications liées à l'abonnement).

### `Notification`
Notification persistée adressée à un utilisateur (historique in-app, trace de
l'envoi push).
- Champs clés : `userId`, `category` (`workout_reminder | progress |
  subscription | system`), `title`, `body`, `data` (JSON : payload de deep-link
  uniquement), `sentAt`, `readAt` nullable.
- Relations : n–1 `User`.
- Index : `(user_id, created_at DESC, id)` ; purge programmée des anciennes
  lignes lues.

### `NotificationPreference`
Consentement par utilisateur × canal × catégorie.
- Champs clés : `userId`, `channel` (`push | email`), `category`, `enabled`.
  Unique `(userId, channel, category)`.
- Relations : n–1 `User`.

### `PushDevice`
Jeton FCM enregistré pour un appareil.
- Champs clés : `userDeviceId` (→ `UserDevice`), `token` (**unique**),
  `platform`, `lastRegisteredAt`, `disabledAt` nullable (jeton signalé invalide
  par FCM — jamais re-sollicité).
- Relations : n–1 `UserDevice` (et via lui, `User`).

---

## Administration — Étape 7 (implémenté)

> Implémenté (migration `20260807070624_administration`), conforme à la cible.
> Précisions : `AdminUser.email` est un `String` unique normalisé en
> minuscules par la couche application (même convention que `User`, pas de
> `citext`) ; les jetons admin portent une **audience JWT dédiée**
> (`carlys-admin`, 12 h, sans refresh — jamais interchangeables avec les
> jetons mobiles) ; le RBAC est seedé depuis la liste `ADMIN_PERMISSIONS`
> de `packages/api-contracts` (le code est la source de vérité) avec les
> rôles `superadmin`, `support` et `content-manager` ; la suspension d'un
> utilisateur révoque immédiatement toutes ses sessions.

Back-office (`apps/admin`) : comptes **séparés** des comptes mobiles, RBAC, et
journal d'audit immuable.

### `AdminUser`
Compte d'administration, jamais confondu avec `User`.
- Champs clés : `email` (`citext`, unique), `passwordHash` (Argon2id),
  `displayName`, `status` (`active | disabled`), `lastLoginAt`.
- Relations : n–n `AdminRole` (table de jointure) ; 1–n `AuditLog` (en tant
  qu'acteur).

### `AdminRole`
Rôle nommé (ex. `support`, `content_manager`, `superadmin`).
- Champs clés : `slug` (unique), `name`, `description`.
- Relations : n–n `AdminUser` ; n–n `AdminPermission` (table de jointure).

### `AdminPermission`
Permission granulaire, seedée par le code (le code est la source de vérité de
la liste des permissions).
- Champs clés : `resource` (ex. `exercise`, `user`, `subscription`), `action`
  (`read | create | update | delete | publish | grant`).
  Unique `(resource, action)`.
- Relations : n–n `AdminRole`.

### `AuditLog`
Journal **append-only et immuable** (jamais de `UPDATE`/`DELETE` applicatif) de
toute action sensible : actions admin, événements de sécurité (révocation de
famille de sessions, détection de réutilisation de refresh token), attributions
manuelles d'entitlements.
- Champs clés : `id`, `actorType` (`admin | user | system`), `actorId`
  nullable, `action`, `resourceType`, `resourceId` nullable, `requestId`
  (corrélation directe avec les logs Pino et l'en-tête `x-request-id`),
  `metadata` (JSON : diff avant/après, contexte — usage légitime), `ip`,
  `createdAt`.
- Relations : volontairement **sans clé étrangère** vers les ressources
  auditées (le journal doit survivre à leur suppression) ; référence logique
  par `(resourceType, resourceId)`.
- Index : `(resource_type, resource_id, created_at DESC)`,
  `(actor_type, actor_id, created_at DESC)`.

---

## Communauté (implémenté)

> Amis, encouragements, défis collectifs et modération. Les règles métier
> (réponses opaques, refus opposable 30 jours, blocages, signalements, jeu du
> mois) sont décrites dans [`docs/product/community.md`](../product/community.md) ;
> ici, seulement la forme des tables.

### `Friendship`
UNE ligne par paire, direction conservée (qui a demandé).
- Champs clés : `requesterId`, `addresseeId`, `status`
  (`PENDING | ACCEPTED | DECLINED`), `respondedAt`.
  Unique `(requesterId, addresseeId)` ; la symétrie est imposée par le
  service. Une ligne `DECLINED` survit au blocage : elle porte le délai.
- Relations : n–1 `User` (deux fois, `Cascade`).

### `Encouragement`
Mot d'un ami ; le nom de l'expéditeur est lu au moment de servir.
- Champs clés : `senderId`, `recipientId`, `message`.
- Relations : n–1 `User` (deux fois, `Cascade`) ; référencé par
  `CommunityReport` (`SetNull`).
- Index : `(recipient_id, created_at DESC)`.

### `CommunityChallenge`
Défi collectif du MOIS, matérialisé paresseusement depuis le catalogue en
code (jamais créé par un utilisateur).
- Champs clés : `slug`, `month` (`YYYY-MM` en UTC, clé d'idempotence du jeu
  du mois), `kind` (`SPORT | CULTURE`), `title`, `description`, `target`,
  `startsAt`, `endsAt`. **Unique `(slug, month)`** : deux lectures
  concurrentes d'un mois vierge ne créent jamais deux fois le même défi.
- Index : `(month)`, `(ends_at)`.

### `ChallengeParticipation`
Participation et `contribution` individuelle à l'objectif collectif.
- Clé primaire composée `(challengeId, userId)` ; `joinedAt`.
- Relations : n–1 `CommunityChallenge`, n–1 `User` (`Cascade`).

### `CommunityPreference` et `QuizAnswer`
- `CommunityPreference` : `userId` (clé), `sharesProgress` (absence = partagé).
- `QuizAnswer` : réponse de l'Academy, unique `(userId, lessonId, answeredOn)`
  (jour LOCAL de l'appareil) — la source des défis `CULTURE`.

### `CommunityBlock`
Blocage unilatéral et opaque.
- Champs clés : `blockerId`, `blockedId`. Unique `(blockerId, blockedId)` ;
  consulté dans les DEUX sens partout où deux personnes se rencontrent.
- Relations : n–1 `User` (deux fois, `Cascade`). Index : `(blocked_id)`.

### `CommunityReport`
Signalement lu et résolu par l'administration (permission
`community:moderate`), jamais visible de la personne signalée.
- Champs clés : `reporterId`, `reportedUserId`, `encouragementId` nullable
  (`SetNull` si le message est retiré), `encouragementMessage` nullable
  (cliché du texte visé, pris dans la même transaction que le signalement :
  la preuve survit au retrait du message), `reason`
  (`HARCELEMENT | SPAM | CONTENU_INAPPROPRIE | AUTRE`), `details`,
  `status` (`OPEN | RESOLVED`), `resolvedAt`.
- Index : `(status, created_at DESC)`, `(reported_user_id)`.

---

## Documents liés

- `docs/api/README.md` — enveloppes de réponse, pagination par curseur,
  `x-request-id`.
- `docs/architecture/backend.md` — modules NestJS qui porteront ces domaines.
- `apps/api/prisma/schema.prisma` — état réel du schéma (vide à l'Étape 1).
- `infrastructure/database/init/01-init.sql` — `citext` + base `carlys_test`.
