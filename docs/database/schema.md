# Modèle de données (PostgreSQL + Prisma)

> **Statut : décrit le schéma RÉEL.** `apps/api/prisma/schema.prisma` fait foi :
> ce document en donne la carte et les raisons, domaine par domaine. Les
> modèles marqués « différé » (dans le tableau des domaines ET dans le titre
> de leur section) n'existent PAS ; ils restent ici parce qu'ils disent ce
> qui a été écarté et pourquoi. Tout le reste est une table en base, décrite
> sous ses noms Prisma — conventions comprises, qui disent aussi ce qui a
> été écarté (`citext`, `snake_case` physique).
>
> Les nombres de modèles et de migrations ne sont pas recopiés ici, ils se
> comptent. Et un modèle du schéma absent de ce document se trouve en une
> commande (à relancer après chaque migration ; elle doit ne rien rendre) :
>
> ```bash
> grep -c '^model ' apps/api/prisma/schema.prisma          # modèles
> ls -d apps/api/prisma/migrations/*/ | wc -l             # migrations
> for m in $(awk '$1=="model"{print $2}' apps/api/prisma/schema.prisma); do
>   grep -q "\`$m\`" docs/database/schema.md || echo "absent : $m"
> done
> ```

Base : PostgreSQL 17 (dev : `postgres:17-alpine` via `docker-compose.yml`),
accédée exclusivement via Prisma 6 depuis `apps/api`. L'extension `citext` et la
base `carlys_test` sont créées par `infrastructure/database/init/01-init.sql`.
Les migrations s'appliquent via `prisma migrate deploy` **avant** la bascule du
trafic, jamais au démarrage du conteneur ; la CI (`api-ci.yml`) échoue si une
migration manque par rapport au schéma, ou si une migration déjà publiée a été
renommée, supprimée ou modifiée — la règle, et la réparation d'un serveur
tombé dans ce cas : [migrations.md](migrations.md).

## Domaines et tranches verticales

| Domaine | Modèles | Tranche |
|---|---|---|
| Identité | `User`, `UserProfile`, `UserCredential`, `UserSession`, `RefreshToken`, `EmailVerification`, `PasswordReset`, `ExternalIdentity` — **implémenté** (migration `20260806180000_auth_foundation` ; connexion Apple et Google branchée sur `ExternalIdentity`) ; `UserDevice` abandonné (le jeton push est rattaché à la session, voir `DeviceToken`) ; `UserPreference` différé | Étape 2 ✅ |
| Catalogue d'exercices | `Exercise`, `ExerciseMuscle`, `ExerciseEquipment`, `MuscleGroup`, `Equipment` — **implémenté** (migration `20260806220000_exercise_catalog`, contenu français directement sur `Exercise`) ; matériel possédé par un membre : `UserEquipment` ; `ExerciseTranslation`, `ExerciseMedia`, `ExerciseVariant`, `CustomExercise` différés | Étape 3 ✅ |
| Médias | `MediaAsset` — **implémenté** (migration `20260809140000_media_assets`) | Étape 3 ✅ |
| Programmes | `WorkoutTemplate`, `WorkoutTemplateExercise`, `WorkoutTemplateSet`, `WorkoutSessionPlanItem` — **implémenté** (migrations `20260808135805_workout_templates` et `20260808153828_workout_session_plan_items` ; modèles de séance autonomes, plan de séance persisté pour la reprise multi-appareil, ids générés sur l'appareil) ; programmes multi-semaines `Program` et `ProgramDay` — **implémenté** (migration `20260809170000_programs`, date de début `20260919185324_calendrier_date`, génération `20260919163304_generation_de_programme`), voir [Programmes](#programmes--livré) | Étape 4 ✅ |
| Séances | `WorkoutSession`, `WorkoutSet` — **implémenté** (migration `20260807010000_workout_sessions`, ids générés sur l'appareil, écritures idempotentes ; provenance et cibles ajoutées par `20260808135805_workout_templates`) ; `WorkoutSessionExercise` fusionné dans `WorkoutSet` (`exerciseId` + `exerciseName` dénormalisé), `WorkoutNote` porté par `WorkoutSession.notes`, `PersonalRecord` livré à l'Étape 5 | Étape 4 ✅ |
| Progression | `PersonalRecord`, `BodyMetric` — **implémenté** (migration `20260807040000_progress`, records recalculés à la clôture, mesures idempotentes) ; `ProgressMilestone` (franchissements, migration `20260922113702_franchissements`) ; `ProgressGoal` et `ProgressSnapshot` différés (agrégats calculés à la volée) | Étape 5 ✅ |
| Abonnements | `SubscriptionPlan`, `SubscriptionPlanEntitlement`, `SubscriptionProduct`, `Subscription`, `SubscriptionEvent`, `UserEntitlement` — **implémenté** (migrations `20260807064832_subscriptions`, `20260915140000_plan_entitlements` et `20260927100000_evenement_paiement_compte`) | Étape 6 ✅ |
| Notifications | `DeviceToken`, `NotificationPreference` — **implémenté** (migrations `20260811210000_device_tokens`, `20260816120000_notification_preferences`, `20260926200000_jetons_push_par_session`) ; `Notification` (historique in-app) différé | ✅ |
| Administration | `AdminUser`, `AdminRole`, `AdminPermission`, jointures `AdminUserRole` et `AdminRolePermission`, `AuditLog` enrichi (`actorType`, `resourceType`/`resourceId`, `requestId`) — **implémenté** (migration `20260807070624_administration` ; `AuditLog` introduit dès l'Étape 2) | Étape 7 ✅ |
| Coach IA | `CoachConversation`, `CoachMessage`, `CoachSessionProposal`, `CoachSessionProposalItem`, `CoachProgramProposal`, `CoachGeneration` — **implémenté** (migrations `20260809120000_coach_ia`, `20260930145758_coach_programme_propose`, `20260930194717_coach_passerelle_generations`) | ✅ |
| Journal alimentaire | `MealEntry`, `Food`, `MealComponent`, `MealPhoto` — **implémenté**, voir [Journal alimentaire](#journal-alimentaire-et-base-daliments-implémenté) | ✅ |
| Communauté | `Friendship`, `Encouragement`, `CommunityChallenge`, `ChallengeParticipation`, `CommunityPreference`, `QuizAnswer`, `CommunityBlock`, `CommunityReport`, `FriendChallenge`, `FriendChallengeMember`, `LeagueMembership` — **implémenté** (migrations `20260811120000_community`, `20260811190000_quiz_answers`, `20260830120000_friend_codes`, `20260906100000_community_moderation`, `20260906110000_community_monthly_challenges`, `20260906130000_community_report_snapshot`, `20260919201000_defis_entre_amis`, `20260919225014_ligues`, `20260924120000_ligues_groupes_de_vingt`) — voir la section [Communauté](#communauté-implémenté) | Vague 1 ✅ |

## Conventions transverses

Ces règles décrivent le schéma **tel qu'il est** ; elles ne sont pas
répétées modèle par modèle. Deux d'entre elles ont longtemps été écrites
comme la cible (`citext`, noms physiques en `snake_case`) : elles sont
signalées ici comme écartées, pour qu'on ne les cherche pas en base.

- **Identifiants** : UUID (`String @db.Uuid`) en clé primaire `id` pour les
  entités ; les tables de jointure et les tables 1–1 ont une clé composée
  (`@@id`) ou la clé du parent (`UserProfile.userId`). Le serveur n'appelle
  pas `gen_random_uuid()` : c'est le client Prisma qui tire l'UUID
  (`@default(uuid())`). Une entité créée sur l'appareil, hors ligne, n'a
  PAS de `@default` : son identifiant vient du client (paquet `uuid`
  Flutter) ou est dérivé par le serveur, ce qui rend la synchronisation
  rejouable — séances et séries, modèles de séance, programmes, mesures,
  repas, défis entre amis, fils du coach, médias déposés.
- **Dates** : `DateTime` Prisma, soit `timestamp(3)` SANS fuseau en
  PostgreSQL (aucun `@db.Timestamptz` dans le schéma). Prisma y écrit et en
  relit de l'UTC : c'est cette convention, pas le type de colonne, qui
  tient l'UTC. Nommage `*At` (`createdAt`, `expiresAt`, `measuredAt`…). Les
  dates CIVILES sont en `@db.Date` (`Program.startsOn`). L'affichage local
  est l'affaire des clients.
- **Horodatage** : `createdAt` (défaut `now()`) et `updatedAt`
  (`@updatedAt`) sur la plupart des entités, pas sur toutes : les tables
  append-only, les jetons et les sessions n'ont que `createdAt` (`AuditLog`,
  `UserSession`, `RefreshToken`, `CoachMessage`…), `SubscriptionEvent` a
  `receivedAt`, et les jointures n'ont aucun horodatage (`ExerciseMuscle`,
  `AdminUserRole`…). Le schéma fait foi, modèle par modèle.
- **Suppression logique** : `deletedAt` nullable là où l'historique doit
  survivre à la suppression — `User`, `Exercise`, `MediaAsset`,
  `WorkoutTemplate`, `Program`, `WorkoutSession`, `WorkoutSet`,
  `BodyMetric`, `MealEntry`, `CoachConversation`. Aucun index unique
  partiel : l'adresse d'un compte supprimé est réécrite en valeur tombale
  (`supprime+<id>@carlys.invalid`), ce qui libère l'originale sous un
  `@unique` ordinaire. Les jetons d'e-mail (`EmailVerification`,
  `PasswordReset`) et les sessions ne sont PAS purgés par une tâche : les
  sessions partent avec le compte (suppression ou purge), les jetons
  expirent et restent.
- **E-mail** : `String @unique`, normalisé (`trim` puis minuscules) par la
  couche application avant toute lecture ou écriture (`normalizeEmail`) —
  `User` comme `AdminUser`. Écarté : le type `citext`. L'extension est
  installée par `01-init.sql`, mais aucune colonne ne la porte.
- **Nommage physique** : AUCUN `@map` ni `@@map` dans le schéma. Les tables
  portent le nom du modèle (`"User"`, `"AuditLog"`, `"WorkoutSession"`) et
  les colonnes celui du champ (`"userId"`, `"createdAt"`), guillemets
  compris en SQL brut (`*.sql.ts`). Écarté : le `snake_case` physique.
  Énumérations métier en `enum` Prisma (enums PostgreSQL natifs).
- **Pagination par curseur** : les listes paginées le sont par curseur
  (`DEFAULT_PAGE_SIZE = 20`, `MAX_PAGE_SIZE = 100`,
  `packages/shared-config`), sur un index qui couvre l'ordre de tri — ex.
  `@@index([userId, startedAt(sort: Desc)])` sur `WorkoutSession`.
- **Transactions** : toute opération multi-tables critique est exécutée en
  transaction Prisma — rotation de refresh token, ingestion d'une séance,
  traitement d'un webhook d'abonnement (événement + abonnement +
  entitlements), suppression puis purge d'un compte.
- **Champs JSON** : réservés aux métadonnées de systèmes externes, aux payloads
  bruts de webhooks, au contexte de l'audit et aux configurations réellement
  variables. **Jamais** pour remplacer une relation ou une colonne
  interrogeable.
- **Contraintes structurantes** (noms Prisma, tels qu'au schéma) :

| Contrainte | Où | Pourquoi |
|---|---|---|
| `email @unique` (normalisé par l'application) | `User`, `AdminUser` | un compte par adresse ; l'adresse d'un compte supprimé est réécrite, donc libérée |
| `id` fourni par l'appareil (clé primaire) | `WorkoutSession`, `WorkoutSet`, `BodyMetric`, `MealEntry`… | une écriture rejouée retombe sur la même ligne : c'est l'idempotence de la synchronisation, sans colonne `idempotency_key` |
| `@@unique([provider, externalEventId])` | `SubscriptionEvent` | un événement webhook traité une seule fois |
| `@@unique([provider, subject])` | `ExternalIdentity` | une identité Apple ou Google liée à un seul compte |
| `@@unique([userId, exerciseName, recordType])` | `PersonalRecord` | un record courant par type |
| `token @unique` (FCM) | `DeviceToken` | un jeton push enregistré une seule fois |
| `storageKey @unique` | `MediaAsset` | deux médias ne partagent jamais un objet du stockage |

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
> n'a jamais été créé — les métadonnées d'appareil vivent sur `UserSession`,
> et le jeton push (`DeviceToken`) est rattaché à la session qui l'a
> enregistré.

### `User`
Racine de l'identité d'un membre (application mobile). Aucune donnée sensible
d'authentification ici.
- Champs clés : `id`, `email` (`String @unique`, normalisé par
  l'application), `status` (`ACTIVE | SUSPENDED | DELETED`),
  `emailVerifiedAt`, `deletedAt`.
- Relations : 1–1 `UserProfile`, `UserCredential` ; 1–n `UserSession`,
  `DeviceToken`, `ExternalIdentity`, `EmailVerification`, `PasswordReset`,
  et vers tous les domaines métier (séances, mesures, abonnements…), tous en
  `onDelete: Cascade` sauf `AuditLog` (`SetNull`) : c'est ce qui permet à
  `deleted-accounts-purge` d'effacer un compte d'un seul `DELETE`. Chaque
  clé que cette cascade traverse a son index (migration
  `20260926200100_index_cles_de_la_purge`, vérifié par
  `test/purge-index.e2e-spec.ts`).
- Suppression par la personne (ou par l'exploitation, sur sa demande
  écrite) : abonnement Stripe résilié d'abord, puis `status = DELETED`,
  `deletedAt` posé, adresse et code ami réécrits en valeurs tombales,
  retrait immédiat de la communauté ; effacement définitif 30 jours plus
  tard, ou tout de suite sur demande écrite (`SECURITY.md`, « Données
  personnelles »).

### `UserProfile`
Données de présentation et de contexte, séparées de l'identité pour garder
`User` minimal.
- Champs clés : `userId` (clé), `displayName`, `birthDate`, `heightCm`,
  `locale`, `timezone`. Pas d'avatar ni de système d'unités : tout est
  stocké en métrique.
- Choix d'usage, tous nullables : `carlysProfile` (profil Carlys),
  `mentorStyle` (voix du Mentor, envoyée au coach IA), `trainingGoal`,
  `trainingExperience`, `weeklySessionsTarget`, `sessionMinutesTarget`
  (entrées de la génération de programme ; migrations
  `20260812090000_carlys_profiles`, `20260917175451_mentor_style`,
  `20260917190658_training_goal`,
  `20260917192528_training_generation_inputs`).
- Profil métabolique (migration `20260807171346_nutrition_profile`) : `sex`
  (`MALE | FEMALE`, nullable), `activityLevel` (`SEDENTARY → VERY_ACTIVE`,
  nullable), `nutritionGoal` (`LOSE_WEIGHT | MAINTAIN | GAIN_MUSCLE`,
  nullable) — consommés par `GET /nutrition/metabolism` ; le poids n'est
  **pas** stocké ici, il provient de la dernière `BodyMetric` `WEIGHT_KG`.
- Relations : 1–1 `User`.

### `UserCredential`
Secret de connexion, isolé dans sa propre table pour restreindre les chemins de
lecture.
- Champs clés : `userId` (unique), `passwordHash` (**Argon2id**, jamais exposé
  par l'API), `passwordUpdatedAt`.
- Relations : 1–1 `User`. Un compte né d'une connexion Apple ou Google n'a
  pas de ligne ici, jusqu'à ce que « Mot de passe oublié » en pose une.

### `UserSession` (implémenté)
Une session **par appareil**. L'access token JWT référence la session (claim
`sid`) : le guard vérifie son état en base à chaque requête, la révoquer
invalide donc immédiatement ses access tokens.
- Champs clés : `userId`, `deviceName`, `devicePlatform`, `ipAddress`,
  `userAgent`, `expiresAt` (expiration **glissante**, repoussée à chaque
  rotation), `lastUsedAt`, `revokedAt`, `revokedReason`
  (`logout | user_revoked | user_revoked_all | password_reset |
  password_changed | refresh_reuse_detected | admin_suspension |
  social_link_unverified_email`). La suppression du compte, elle, SUPPRIME
  les sessions au lieu de les révoquer.
- Relations : n–1 `User` ; 1–n `RefreshToken` ; 1–n `DeviceToken` (les
  jetons push tombent avec la session).
- **Durée** : une session close — révoquée, ou expirée faute de
  renouvellement — est effacée 30 jours après, avec ses jetons, par la
  passe quotidienne de `deleted-accounts-purge`
  (`DEAD_SESSION_RETENTION_DAYS`) : elle porte une adresse IP et un
  user-agent.
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
- **Durée** : chaque rotation écrit une ligne ; un jeton échu depuis plus de
  30 jours est effacé par la même passe quotidienne. Compromis assumé : un
  jeton `ROTATED` présenté révoque sa session (le piège qui éjecte un voleur
  de la chaîne) ; effacé, il ne rend plus qu'un 401. Le piège tient donc
  TTL + 30 jours après l'émission (60 par défaut). Le borner autrement
  demande une durée de vie absolue de session — une décision produit.
  Balayage sans index sur `expiresAt`, une fois par jour, sur une table que
  la purge garde bornée ; un échec de cette passe est rapporté sans retarder
  l'effacement des comptes.
- Index : `(session_id)`.

### `UserDevice` (abandonné)
Un appareil logique séparé de la session n'a jamais été nécessaire : le push
est arrivé avec `DeviceToken`, rattaché à la session (section
[Notifications](#notifications-implémenté)). Il n'existe pas en base.

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
Lien vers un fournisseur d'identité externe, utilisé par `POST /auth/social`
(connexion Apple et Google).
- Champs clés : `userId`, `provider` (`APPLE | GOOGLE`), `subject` (claim
  `sub` du jeton d'identité ; unique composé `(provider, subject)`), `email`
  rapporté par le fournisseur, `createdAt`.
- Relations : n–1 `User` (un utilisateur peut lier plusieurs fournisseurs).
  Supprimée avec le compte dès `DELETE /users/me`, sans attendre la purge.

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
> `pnpm prisma:seed` : 190 exercices, 12 groupes musculaires, 15 équipements, et les photos du catalogue déposées dans le stockage objet).
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

Catalogue officiel (seed ≥ 30 exercices, `pnpm prisma:seed`), en français,
servi avec cache Redis (lecture intensive, écriture rare — invalidation à la
publication).

### `Exercise`
Exercice du catalogue officiel, contenu en français directement sur la ligne
(pas de table de traductions).
- Champs clés : `id`, `slug` (unique, stable pour le cache et les URLs),
  `name`, `description`, `instructions` (`String[]`, étapes ordonnées),
  `difficulty` (`BEGINNER | INTERMEDIATE | ADVANCED`), `type`
  (`STRENGTH | CARDIO | MOBILITY | STRETCHING`), `isPremium`,
  `isPublished`, `deletedAt`, `tags` (`String[]`), `imageId` et `meshId`
  (→ `MediaAsset`, `SetNull`).
- Relations : 1–n `ExerciseMuscle`, `ExerciseEquipment` ; référencé par les
  séries, les modèles de séance, les plans de séance, les records et les
  propositions du coach. Index : `(isPublished, name)`, `(deletedAt)`.

### `ExerciseTranslation` — différé

N'existe PAS : le contenu est en français sur `Exercise`. Prévu avec l'i18n :
`exerciseId`, `locale`, `name`, `shortDescription`, `instructions`, unique
`(exerciseId, locale)`.

### `ExerciseMedia` — différé

N'existe PAS : un exercice porte directement sa photo (`imageId`) et son
maillage (`meshId`). Prévu pour plusieurs médias ordonnés par exercice :
`exerciseId`, `mediaAssetId`, `role`, `position`.

### `MuscleGroup`
Référentiel des groupes musculaires (seedé, quasi immuable).
- Champs clés : `slug` (unique), `name`, `sortOrder`.
- Relations : 1–n `ExerciseMuscle`.

### `ExerciseMuscle`
Jointure exercice ↔ groupe musculaire, qualifiée.
- Champs clés : `exerciseId`, `muscleGroupId`, `role`
  (`PRIMARY | SECONDARY`). Clé primaire `(exerciseId, muscleGroupId)`,
  index `(muscleGroupId)`.
- Relations : n–1 `Exercise`, n–1 `MuscleGroup`.

### `Equipment`
Référentiel du matériel (barre, haltères, poids du corps…), seedé.
- Champs clés : `slug` (unique), `name`.
- Relations : n–n `Exercise` par `ExerciseEquipment` ; n–n `User` par
  `UserEquipment`.

### `UserEquipment`
Le matériel dont un membre dispose, déclaré à la préparation d'un programme
et lu par la génération.
- Clé primaire `(userId, equipmentId)`, `createdAt`.
- Relations : n–1 `User`, n–1 `Equipment` (`Cascade` des deux côtés).
  Index : `(equipmentId)`.

### `ExerciseVariant` — différé
N'existe PAS. Prévu : lien orienté entre deux exercices du catalogue (« variante de » : inclinaison,
prise, unilatéral…).
- Champs clés : `exerciseId`, `variantExerciseId`, `variationType`.
  Unique `(exerciseId, variantExerciseId)` ; contrainte `CHECK` interdisant
  l'auto-référence.
- Relations : n–1 `Exercise` (deux fois).

### `CustomExercise` — différé
N'existe PAS. Prévu : exercice créé par un utilisateur, **privé** (jamais visible d'un autre compte),
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
Fichier déposé depuis l'ADMINISTRATION et servi par le stockage objet public
(MinIO en développement comme sur le serveur, bucket `S3_BUCKET`, créé par le
service `minio-init` du compose). La base ne stocke **jamais** le binaire.
Les photos de repas des membres n'en sont PAS : elles vivent dans le bucket
privé, sous `MealPhoto` (voir « Journal alimentaire »).
- Champs clés : `id` (fourni par l'administration : un dépôt rejoué ne crée
  pas de doublon), `kind` (`IMAGE | MESH_3D | VIDEO`), `storageKey` (unique,
  chemin objet), `mimeType`, `byteSize`, `width`/`height` (images et vidéos
  seulement), `checksum` (SHA-256 du contenu), `originalName`,
  `uploadedById` (→ `AdminUser`, `SetNull`), `deletedAt`. Pas de statut
  d'envoi : le dépôt est synchrone.
- Relations : n–1 `AdminUser` (optionnelle) ; référencé par `Exercise`
  (`imageId` pour la photo, `meshId` pour le maillage, `SetNull` des deux
  côtés). Index : `(kind, createdAt)`, `(checksum)`.

---

## Programmes — livré

Structures **prescriptives** (ce qui est prévu), distinctes des séances
**réalisées**.

> **Ce qui était décrit ici ne l'a jamais été livré.** Trois modèles étaient
> annoncés — `TrainingProgram`, `ProgramWeek`, `ProgramDay` — avec un champ
> `goal`, un `level`, un `ownerId` nullable et des semaines réifiées. La
> migration `20260809170000_programs` en a livré DEUX, sans aucun de ces
> champs. Qui codait d'après cette page construisait à côté du réel ; elle
> décrit maintenant ce qui existe.

### `Program`
Un plan sur plusieurs semaines, propre à un utilisateur.
- Champs clés : `id` (fourni par le client), `userId` **non nul**, `name`,
  `description` nullable, `weeksCount` (1 à 52), `isActive`, `startsOn`
  (`date` nullable, le « Premier jour » : migration
  `20260919185324_calendrier_date`), `generationReport` (JSON nullable,
  migration `20260919163304_generation_de_programme`), `deletedAt`.
- `isActive` : **un seul programme suivi à la fois**. PostgreSQL ne peut pas
  l'exprimer ici — il faudrait un index unique PARTIEL, hors du vocabulaire
  Prisma — c'est donc le service qui l'impose, en désactivant les autres dans
  la même transaction.
- Relations : n–1 `User` (obligatoire) ; 1–n `ProgramDay`.
- Index : `[userId, updatedAt desc]`.

### `ProgramDay`
Une case du calendrier : semaine N, jour J. **Il n'y a pas de `ProgramWeek`** :
la semaine est un simple entier porté par le jour.
- Champs clés : `programId`, `weekNumber` (1 à `weeksCount`), `dayOfWeek`
  (1 lundi à 7 dimanche), `templateId` nullable, `label`, `isRest`.
- `label` : nom du modèle figé à l'enregistrement, ou texte libre (« Repos »,
  « Course »). Il garde un sens même sans modèle.
- `templateId` en `SetNull` : supprimer un modèle vide la case, il ne fait
  jamais disparaître le programme.
- Unique `(programId, weekNumber, dayOfWeek)`.

**La date d'une case se calcule, elle n'est pas stockée.** `dayOfWeek` reste
une colonne de la case, verrouillée par la contrainte d'unicité : la
prescription (« ce jour-là, ce modèle ») et le placement dans la semaine sont
le même objet. Depuis `startsOn`, la date civile d'une case vaut
`dateOfSlot(anchorOf(startsOn), weekNumber, dayOfWeek)`. Conséquence
défendue par l'API : un `PUT /programs/:id` qui changerait la DATE d'une case
déjà honorée par une séance terminée (en changeant son jour, ou le premier
jour du programme vers une autre semaine) est refusé en **409**
(`programs.service.ts`, `test/programme-case-faite.e2e-spec.ts`).

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
- `revision` (`Int`, défaut 1 ; migration
  `20260927300000_revision_des_seances`) : +1, EN BASE et dans la même
  transaction, à chaque écriture qui change ce que le détail sert — la
  séance, l'une de ses séries (suppression douce comprise), son plan, sa
  case du calendrier (`programDayId`). Ce sont des DÉCLENCHEURS PostgreSQL
  qui l'incrémentent (migration `20260927400000_revision_des_seances_en_base` :
  +1 par mise à jour de la séance, +1 par instruction qui écrit ses séries
  ou son plan), pas le code : un retour arrière du déploiement, qui remet le
  code d'avant sans défaire le schéma, ne la fausse pas. Jamais sur une
  lecture ni sur un rejeu sans effet (une instruction qui ne touche aucune
  ligne ne fait rien monter). Servie dans la liste et le détail : le rapatriement
  mobile saute une séance dont la révision n'a pas bougé
  (`docs/synchronization/offline-first.md`). Un compteur et non le plus
  grand `updatedAt` : Prisma date AVANT la validation, et une écriture
  validée après une autre mais datée avant elle ne ferait jamais monter le
  maximum. Le code ne l'écrit JAMAIS à la main ; une nouvelle écriture de
  ces tables doit seulement ne toucher aucune ligne quand rien ne change
  (les filtres de rejeu de `WorkoutsRepository` et
  `ProgramsRepository.linkSessionToDay`).
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
- `doneSetId` n'a **pas d'index non plus**, et toute requête qui le filtre
  nomme aussi `sessionId` : une série n'honore qu'une prévision de SA séance,
  et c'est l'index `sessionId` qui sert alors. Libérer la prévision d'une
  série supprimée sur `doneSetId` seul balayait le plan de tous les comptes
  (2 millions de lignes, 0,3 s, mesuré en septembre 2026).
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
- Réel : voir « Progression » ci-dessous. `sessionId` est indexé : la
  cascade d'effacement d'un compte y passe (`SET NULL`) pour chaque séance,
  et sans index chaque séance balayait la table entière.

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

### `ProgressMilestone` (implémenté)
Journal des FRANCHISSEMENTS d'un membre (migration
`20260922113702_franchissements`) : records battus (dérivés des séries à la
clôture), récompenses du catalogue (poussées par le moteur du mobile) et
paliers de titre.
- Champs clés : `userId`, `kind` (`RECORD | REWARD | TITLE`), `key` (clé
  stable du franchissement), `occurredAt`, `payload` (JSON nullable).
  Unique `(userId, kind, key)` : rejouer un envoi n'écrit rien.
- Index : `(userId, occurredAt DESC)`.
- Relations : n–1 `User` (`Cascade`).

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
- Relations : 1–n `SubscriptionProduct`, `Subscription`,
  `SubscriptionPlanEntitlement`.

### `SubscriptionPlanEntitlement`
Les droits qu'un plan ouvre — **la correspondance plan → entitlements, en
donnée**. C'est ce que l'ADR 0006 exige (« aucun test de nom de plan en dur ;
toute condition d'accès nomme un droit ») et ce qui manquait : le calcul des
droits reconnaissait le plan à son slug, puis réécrivait la liste des droits
premium codée dans `packages/api-contracts`. Un second plan payant aurait donc
rétrogradé, par son propre achat, un membre déjà Premium.
- Champs clés : `planId`, `entitlementKey` — clé primaire composite.
- Relations : n–1 `SubscriptionPlan` (`onDelete: Cascade`).
- `entitlementKey` est un `TEXT` et non un `enum` : ajouter un droit ne doit
  pas demander une migration de type. Le contrat
  (`ENTITLEMENT_KEYS`) reste l'autorité sur ce qui est LISIBLE — une clé qu'il
  ne connaît pas est ignorée à la lecture plutôt que servie, sans quoi la
  validation Zod de la réponse ferait rendre 500 sur un compte sain.
- Reprise de l'existant : migration `20260915140000_plan_entitlements`.

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
  `POST /subscriptions/portal`),
  `lastEventAt` nullable (migration `20260915120000_subscription_event_ordering`).
- **`lastEventAt` est la garde contre le rembobinage.** C'est la date
  d'**émission** du dernier événement appliqué, telle que le fournisseur l'a
  datée (Stripe `created`, RevenueCat `event_timestamp_ms`) — jamais sa date
  de réception. Les webhooks n'arrivent pas dans l'ordre d'émission : un
  réessai après une coupure, ou le parallélisme du fournisseur, suffit à
  livrer un événement ancien après un plus récent, et l'écriture était
  inconditionnelle. Un `customer.subscription.updated` émis **avant** un
  renouvellement mais livré **après** réécrivait la période à jour avec
  l'ancienne : l'accès d'un membre qui venait de payer se coupait jusqu'au
  prochain événement, soit un mois. Un événement strictement plus ancien est
  désormais **ignoré** (pas une erreur : les droits sont recalculés depuis
  l'état courant et l'événement est marqué traité). `null` — les lignes
  d'avant la migration, et tout fournisseur qui ne date pas ses événements —
  laisse passer, faute de pouvoir comparer.
- Relations : n–1 `User`, n–1 `SubscriptionPlan` ; 1–n `SubscriptionEvent`.
- Index : `(user_id, status)`.
- À la suppression du compte, un abonnement Stripe `active`, `trialing` ou
  `past_due` est résilié chez Stripe AVANT la transaction, puis passé
  `canceled` (`cancelAtPeriodEnd` à faux) dedans
  (`SubscriptionsRepository.billableSubscriptions`, `markCanceled`).

### `SubscriptionEvent`
Journal **append-only** des webhooks reçus — la garantie d'idempotence du
domaine.
- Champs clés : `provider`, `externalEventId` (**unique
  `(provider, externalEventId)` : un événement n'est traité qu'une seule
  fois** — l'insertion en conflit court-circuite le retraitement), `eventType`,
  `payload` (JSON brut du webhook — usage légitime du JSON), `receivedAt`,
  `processedAt` nullable, `processingError` nullable, `userId` nullable
  (migration `20260927100000_evenement_paiement_compte`, indexé, **sans clé
  étrangère**) : le compte que l'événement NOMME (`metadata.userId` Stripe,
  `app_user_id` RevenueCat), recopié à la réception. C'est par lui que la
  purge d'un compte retrouve aussi les événements dont la projection a échoué,
  rattachés à aucun abonnement.
- Relations : n–1 `Subscription` (nullable tant que la corrélation n'est pas
  établie).
- **Ce qui n'est PAS gardé** : un événement Stripe hors
  `customer.subscription.*` (facture, paiement : ils portent l'adresse et le
  nom du client, et rien n'est à projeter), un type RevenueCat non suivi, et
  tout événement qui nomme un compte supprimé ou déjà effacé. Ils sont
  acquittés (200) sans être enregistrés ni appliqués : après la purge, la
  projection aurait violé la clé étrangère de l'abonnement (503 réémis en
  boucle). Seule action, et seulement pour un compte SUPPRIMÉ dont la ligne
  existe encore (pas encore effacé par la purge) : un abonnement Stripe qui
  prélève encore est résilié à réception
  (`AccountBillingService.stopForAbsentAccount`). Un compte inconnu de la
  base ou déjà effacé n'entraîne aucune résiliation : rien ne prouve que
  cet abonnement est le nôtre (sauvegarde restaurée, compte Stripe de test
  partagé), et une résiliation est irréversible.
- **Durée** : effacé avec le compte qu'il nomme (purge). Un événement qui
  n'en nomme AUCUN (`userId` nul : achat RevenueCat anonyme, charge Stripe
  sans `metadata.userId`) ne peut être appliqué à personne : jamais traité
  (`processedAt` nul), il est effacé par la passe quotidienne de
  `deleted-accounts-purge` 90 jours après sa réception
  (`ORPHAN_PAYMENT_EVENT_RETENTION_DAYS`, lu sur l'index `receivedAt`).
- Traitement en transaction : insertion de l'événement → mise à jour de
  `Subscription` → recalcul des `UserEntitlement`.
- **`processedAt` à `null` signifie « à rejouer », et la réponse HTTP est ce
  qui déclenche le rejeu.** Le service répondait 200 à tout échec de
  projection, ce qui confond *reçu* et *appliqué* : rien d'autre ne rejouait
  (aucune tâche planifiée), et `processingError` n'était lu par aucun écran.
  Un paiement encaissé dont la projection échouait laissait le compte gratuit,
  définitivement et sans un mot. Désormais : un échec qui peut guérir tout
  seul — produit absent du catalogue, base indisponible — répond **5xx**, et
  le fournisseur réémet (le rejeu est sans effet de bord, l'événement non
  traité étant retraité) ; un échec **définitif** — charge utile inexploitable,
  `metadata.userId` absent — répond 200, puisque la réémettre rendrait le même
  échec.

### `UserEntitlement`
Source de vérité **serveur** des droits effectifs d'un utilisateur, matérialisée
pour une lecture O(1) par l'API et le mobile.
- Champs clés : `userId`, `entitlementKey` (ex. `premium`), `isActive`,
  `expiresAt` nullable, `sourceSubscriptionId` nullable (un entitlement peut
  aussi être accordé manuellement — Étape 7, tracé dans `AuditLog`).
  Unique `(userId, entitlementKey)`.
- Relations : n–1 `User` ; n–1 `Subscription` (optionnelle).

---

## Notifications (implémenté)

Push par FCM uniquement, sans historique en base : le serveur ne garde que ce
qu'il faut pour envoyer (le jeton) et ce que la personne a refusé. Règles
d'envoi et destinations : [`docs/product/notifications.md`](../product/notifications.md).

### `DeviceToken`
Jeton FCM d'un appareil (migrations `20260811210000_device_tokens` et
`20260926200000_jetons_push_par_session`).
- Champs clés : `userId`, `sessionId` (nullable), `token` (**unique** : un
  jeton appartient à un seul compte à la fois, se connecter avec un autre
  compte sur le même appareil le réaffecte), `platform` (`ANDROID | IOS`),
  `createdAt`, `updatedAt`.
- **Rattaché à la session qui l'a enregistré** (`onDelete: Cascade`) :
  révoquer la session supprime ses jetons dans la même transaction, et
  l'envoi ne sert que les jetons d'une session vivante (ni révoquée, ni
  expirée). `sessionId` nul : jeton enregistré avant la migration ; il est
  encore servi, et tombe à la première révocation qui touche le compte.
- Supprimé aussi à la déconnexion (`DELETE /notifications/device-tokens`),
  quand FCM le déclare mort, à la suspension et à la suppression du compte.
- Relations : n–1 `User`, n–1 `UserSession`. Index : `(userId)`,
  `(sessionId)`.

### `NotificationPreference`
Refus par utilisateur × famille de notification (migration
`20260816120000_notification_preferences`).
- Clé primaire `(userId, category)`, `enabled`, `updatedAt`. `category` :
  `FRIEND_REQUESTS | ENCOURAGEMENTS | CHALLENGE_INVITES`. Pas de canal : seul
  le push existe.
- Absence de ligne = famille acceptée. Le refus est appliqué côté serveur,
  avant tout envoi.
- Relations : n–1 `User`.

### `Notification` (différé)
Un historique in-app des notifications n'existe pas : rien n'est persisté
après l'envoi.

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
- Champs clés : `email` (`String @unique`, normalisé en minuscules par
  l'application), `passwordHash` (Argon2id), `displayName`, `status`
  (`ACTIVE | DISABLED`), `lastLoginAt`.
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

### `AdminUserRole` et `AdminRolePermission`
Les deux tables de jointure du RBAC : `(adminUserId, roleId)` et
`(roleId, permissionId)` en clé primaire composée, `Cascade` des deux
côtés. Aucune autre colonne.

### `AuditLog`
Journal **append-only et immuable** (jamais de `UPDATE`/`DELETE` applicatif) de
toute action sensible : actions admin, événements de sécurité (révocation de
famille de sessions, détection de réutilisation de refresh token), attributions
manuelles d'entitlements.
- Champs clés : `id`, `actorType` (`USER | ADMIN | SYSTEM`), `userId` et
  `adminUserId` nullables (l'acteur, selon son type — il n'y a pas de colonne
  `actorId` unique), `action`, `resourceType` et `resourceId` nullables,
  `requestId` (corrélation directe avec les logs Pino et l'en-tête
  `x-request-id`), `metadata` (JSON : diff avant/après, contexte — usage
  légitime ; jamais l'adresse d'un membre en clair : un échec de connexion
  n'y porte que son empreinte, `emailHash`), `ipAddress`, `userAgent`,
  `createdAt`. Les lignes écrites avant l'empreinte à clé ont été vidées une
  fois, au déploiement, par la migration de DONNÉES
  `20260927200000_audit_adresses_et_empreintes_nues` : `metadata.email` en
  clair, ou une `emailHash` datée d'avant le HMAC ou hors de sa forme,
  deviennent `emailHash: null`.
- Relations : volontairement **sans clé étrangère** vers les ressources
  auditées (le journal doit survivre à leur suppression) ; référence logique
  par `(resourceType, resourceId)` — qui garde donc l'UUID d'un compte
  effacé par la purge (`<uuid>`, `<uuid>:<droit>`), comme
  `metadata.reporterId` d'un signalement traité. Les deux colonnes d'acteur, elles, ont
  bien une relation, en `onDelete: SetNull` — c'est la seule nuance à
  « jamais de `UPDATE` applicatif » plus haut : effacer un compte détache ses
  lignes d'audit au lieu de les supprimer, le journal survit à la personne.
- Index (migration `20260915130000_audit_log_indexes`) :
  - `(createdAt, id)` — la SEULE lecture, `listAuditLogs`, pagine sans aucun
    filtre et trie `("createdAt" DESC, "id" DESC)`. Aucun index ne commençait
    par `createdAt` : chaque page du back-office balayait puis triait la
    table entière. Un btree se parcourt dans les deux sens, `DESC` n'a donc
    pas à figurer dans l'index.
  - `(userId, createdAt)` et `(adminUserId)` — pour les `SetNull` ci-dessus,
    pas pour une lecture. Sans eux, effacer un compte balaierait tout le
    journal.
  - Il n'y en a pas d'autre, et c'est délibéré : les index sur `action` et
    `(resourceType, resourceId)` n'avaient AUCUN lecteur — ni filtre au
    contrat, ni filtre au contrôleur — et se payaient à chaque écriture, sur
    une table alimentée à chaque connexion. Ils reviendront avec les filtres
    qui les justifieront.

---

## Coach IA (implémenté)

> Migration `20260809120000_coach_ia`. Règles (outils, plafond quotidien,
> ce qui part chez le fournisseur du modèle) :
> [`docs/product/coach-ia.md`](../product/coach-ia.md).

### `CoachConversation`
Un fil de conversation d'un membre avec le coach.
- Champs clés : `id` (fourni par l'appareil), `userId`, `title` nullable,
  `summary` et `summaryThrough` nullables (la mémoire des messages sortis de
  la fenêtre relue, et le dernier instant qu'elle couvre — ADR 0013),
  `createdAt`, `updatedAt`, `deletedAt`.
- Index : `(userId, updatedAt DESC)`. Relations : n–1 `User` (`Cascade`) ;
  1–n `CoachMessage`.
- La LECTURE de ses propres fils n'est gardée ni par l'abonnement ni par la
  disponibilité du coach ; seuls l'ouverture d'un fil et l'envoi d'un
  message le sont.

### `CoachMessage`
- Champs clés : `id`, `conversationId`, `role`, `content`, `inputTokens` et
  `outputTokens` nullables (volume traité par le modèle), `createdAt`.
- Index : `(conversationId, createdAt)`. Relations : n–1
  `CoachConversation` (`Cascade`) ; 0–1 `CoachSessionProposal` ;
  0–1 `CoachProgramProposal`.

### `CoachSessionProposal` et `CoachSessionProposalItem`
Une séance PROPOSÉE par le coach, jamais écrite dans le compte tant que la
personne ne l'accepte pas.
- `CoachSessionProposal` : `messageId` (unique), `name`,
  `estimatedMinutes`, `sourceTemplateId` (`SetNull`),
  `acceptedSessionId` nullable.
- `CoachSessionProposalItem` : une ligne PAR SÉRIE (`exercisePosition`,
  `exerciseId`, `exerciseName`, `setPosition`, `kind`, `targetReps`,
  `targetWeightKg`, `restSeconds`), unique
  `(proposalId, exercisePosition, setPosition)`.

### `CoachProgramProposal`
Un programme PROPOSÉ par le coach : ses réglages seulement (`goal`,
`weeklySessions`, `sessionMinutes`), que le générateur du module `programs`
transforme en plan quand la personne l'accepte. `messageId` (unique,
`Cascade`), `acceptedProgramId` nullable et SANS clé étrangère (une mesure,
pas un lien). Migration `20260930145758_coach_programme_propose`.

### `CoachGeneration`
La MESURE d'une génération (ADR 0013), jamais son texte : `id` (identifiant
de requête de la passerelle), `userId` (`Cascade`), `conversationId` et
`messageId` SANS clé étrangère (des mesures, pas des liens), `status`
(`QUEUED` → `PROCESSING` → `STREAMING` → `COMPLETED` | `FAILED` |
`CANCELLED`), `createdAt` (entrée dans la file), `startedAt` (créneau
obtenu), `firstTokenAt`, `completedAt`, `inputTokens`, `outputTokens`,
`model`, `worker` (hôte seul), `errorCode` (raison courte). L'attente, la
latence et le délai du premier mot se déduisent des instants. Index :
`createdAt`, `(userId, createdAt)`. Migration
`20260930194717_coach_passerelle_generations`.

---

## Journal alimentaire et base d'aliments (implémenté)

> Repas saisis à la main ou composés d'aliments de la table CIQUAL. Les
> règles (qui fait foi, instantané, import) sont décrites dans
> [`docs/product/nutrition.md`](../product/nutrition.md) ; ici, seulement la
> forme des tables. Migrations `20260925100000_moment_aliments_composition`
> et `20260925140000_photo_repas_privee`.

### `MealEntry`
Un repas, id généré sur l'appareil, `eatenAt` instant UTC, suppression douce.
- Champs clés : `name`, `moment` (`BREAKFAST | LUNCH | DINNER | SNACK`,
  nullable sans défaut : les repas antérieurs n'ont jamais dit le leur),
  `kcal` (entier), `proteinG` / `carbsG` / `fatG` (entiers nullables, `null` =
  inconnu), `quantity` `Decimal(7, 2)` + `quantityUnit` (par paire).
- Saisi à la main quand il n'a aucun `MealComponent` ; COMPOSÉ sinon, et ses
  totaux sont alors calculés par le serveur (`quantityUnit = GRAM`).
- Relations : n–1 `User` (`Cascade`) ; 1–n `MealComponent` ; 1–0..1
  `MealPhoto`.
- Index : `(userId, eatenAt)`.

### `Food`
Un aliment CIQUAL, écrit par `dist/cli/ciqual-import` seulement.
- Clé : `code` (`alim_code` CIQUAL, entier, stable d'une version à l'autre).
- Champs clés : `name`, `shortName` (avant la première virgule), groupe et
  sous-groupe (codes et noms, nullables), `kcalPer100g` `Decimal(7, 2)`
  obligatoire, `kcalComputed` (l'énergie n'est pas publiée par l'Anses, elle
  est calculée depuis les macros, ADR 0016 ; faux par défaut),
  `proteinPer100g` / `carbsPer100g` / `fatPer100g` nullables, `searchKey`
  (nom normalisé), `sourceVersion`, `retiredAt`.
- Jamais supprimé : un aliment disparu d'une version reçoit `retiredAt`.
- Aucun index au-delà de la clé : ~3 200 lignes, la recherche est un
  balayage séquentiel (pas d'extension `pg_trgm`).

### `MealComponent`
Un aliment dans un repas composé, avec l'INSTANTANÉ pris à l'ajout.
- Clé : `id`, UUID généré SUR L'APPAREIL à l'ajout de la ligne et conservé
  d'une correction à l'autre (un identifiant déjà pris par la ligne d'un
  autre repas : 409).
- Champs clés : `mealId`, `foodCode`, `position` (0 à 29), `quantityG`
  `Decimal(7, 2)`, `foodName`, `foodShortName`, `foodGroup`,
  `foodSourceVersion` (exposée comme `sourceVersion`), et les quatre valeurs
  pour 100 g recopiées ; `createdAt`, la date de l'instantané, conservée
  pour une ligne gardée.
- Relations : n–1 `MealEntry` (`Cascade`) ; n–1 `Food` (`Restrict` : la
  base refuse de supprimer un aliment qu'un repas cite).
- Unique : `(mealId, position)`. Une correction remplace toute la liste
  dans une transaction, sous le verrou de la ligne `MealEntry`
  (`SELECT … FOR UPDATE`) : deux corrections simultanées passent l'une
  après l'autre, la seconde jugée sur l'état laissé par la première. Une
  ligne désignée par son `id` y est réécrite avec son instantané, seules sa
  quantité et sa place changent.

### `MealPhoto`
La photo qu'une personne joint à SON repas (migration
`20260925140000_photo_repas_privee`). Donnée personnelle : les octets vivent
dans le bucket PRIVÉ `S3_PRIVATE_BUCKET`, jamais dans le bucket public des
médias ; la ligne ne fait que les décrire.
- Clé : `mealId` (une photo par repas au plus).
- Champs clés : `storageKey` (unique, `meal-photos/<userId>/<uuid>.jpg`, un
  UUID neuf par dépôt), `byteSize` et `sha256` des octets STOCKÉS
  (métadonnées retirées ; l'empreinte sert d'ETag), `updatedAt` (clé de
  cache du client, exposée comme `photo.updatedAt`).
- Relations : 1–1 `MealEntry` (`Cascade`). La ligne part dans la
  transaction de la suppression douce du repas et dans celle de la
  suppression du compte ; l'objet est effacé juste après, hors transaction.
- Écriture : la ligne ne s'écrit que sous le verrou du compte
  (`FOR SHARE` sur `User`) et du repas (`FOR UPDATE` sur `MealEntry`), après
  avoir revérifié que ni l'un ni l'autre n'a été supprimé pendant l'envoi
  des octets ; la suppression du compte verrouille `User` en premier.
- Règle : une ligne = un objet vivant. Un objet que plus aucune ligne (d'un
  repas non supprimé, d'un compte non supprimé) ne cite est un orphelin,
  repris par `dist/cli/meal-photos-sweep`, que la supervision du serveur
  lance une fois par jour.

---

## Communauté (implémenté)

> Amis, encouragements, défis collectifs et modération. Les règles métier
> (réponses opaques, refus opposable 30 jours, blocages, signalements, jeu du
> mois) sont décrites dans [`docs/product/community.md`](../product/community.md) ;
> ici, seulement la forme des tables.

### `Friendship`
UNE ligne par paire, direction conservée (qui a demandé).
- Champs clés : `requesterId`, `addresseeId`, `status`
  (`PENDING | ACCEPTED | DECLINED`), `respondedAt`, plus la PAIRE ordonnée
  `userLowId`/`userHighId` (les deux mêmes identifiants, toujours rangés
  pareil).
  **Unique `(userLowId, userHighId)`** : c'est la BASE qui garantit une seule
  ligne par paire, plus le service. L'unicité dirigée d'avant
  (`requesterId`, `addresseeId`) laissait passer deux lignes dès que les deux
  personnes se demandaient en même temps — chacune lisait « pas de lien »,
  chacune écrivait la sienne, et accepter l'une laissait l'autre en attente
  pour toujours. Une ligne `DECLINED` survit au blocage : elle porte le délai.
- Relations : n–1 `User` (deux fois, `Cascade`).

### `Encouragement`
Mot d'un ami ; le nom de l'expéditeur est lu au moment de servir.
- Champs clés : `senderId`, `recipientId`, `message`.
- Relations : n–1 `User` (deux fois, `Cascade`) ; référencé par
  `CommunityReport` (`SetNull`).
- Ceux qu'un compte a ENVOYÉS sont supprimés dès sa suppression, dans la
  même transaction (`CommunityRepository.deleteEncouragementsSentBy`) ; ceux
  qu'il a reçus partent à la purge.
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
- Clé primaire composée `(challengeId, userId)` ; `joinedAt`, `leftAt?`.
- **La ligne survit au départ** : `leftAt` date la sortie, elle n'efface rien.
  La somme collective porte sur TOUTES les lignes (une contribution versée
  appartient au défi) ; le compte des participants et les incréments, eux, ne
  retiennent que `leftAt IS NULL`. Supprimer la ligne faisait reculer un
  compteur collectif, que tous les autres participants voient. Revenir reprend
  la même ligne (`leftAt` remis à `null`) : rien n'est perdu ni compté deux fois.
- Relations : n–1 `CommunityChallenge`, n–1 `User` (`Cascade`).

### `CommunityPreference` et `QuizAnswer`
- `CommunityPreference` : `userId` (clé), `sharesProgress` (absence =
  partagé), `joinsLeague` (défaut `false` : entrer dans la ligue EST le
  consentement ; `false` retire aussi le nom du classement des autres).
- `QuizAnswer` : réponse de l'Academy, unique `(userId, lessonId, answeredOn)`
  (jour LOCAL de l'appareil) — la source des défis `CULTURE`.

### `CommunityBlock`
Blocage unilatéral et opaque.
- Champs clés : `blockerId`, `blockedId`. Unique `(blockerId, blockedId)` ;
  consulté dans les DEUX sens partout où deux personnes se rencontrent.
- Relations : n–1 `User` (deux fois, `Cascade`). Index : `(blocked_id)`.

### `CommunityReport`
Signalement lu et résolu par l'administration (permission
`community:moderate`), jamais visible de la personne signalée. Il vise la
personne, un encouragement qu'elle a envoyé OU un défi entre amis qu'elle a
créé.
- Champs clés : `reporterId`, `reportedUserId`, `encouragementId` nullable
  (`SetNull` si le message est retiré), `encouragementMessage` nullable
  (cliché du texte visé, pris dans la même transaction que le signalement :
  la preuve survit au retrait du message), `friendChallengeId` nullable
  (défi entre amis visé, exclusif avec `encouragementId`, `SetNull` si le
  défi disparaît), `friendChallengeTitle` et `friendChallengeMessage`
  nullables (clichés du titre et du mot du créateur, pris dans la même
  transaction), `reason`
  (`HARCELEMENT | SPAM | CONTENU_INAPPROPRIE | AUTRE`), `details`,
  `status` (`OPEN | RESOLVED`), `resolvedAt`.
- Index : `(status, created_at DESC)`, `(reported_user_id)`.
- Conservé tant que ni le signalant ni la personne signalée n'est effacé
  (`Cascade` des deux côtés) : même résolu, il reste.

### `FriendChallenge`
Défi lancé par un membre à ses amis (migrations
`20260919201000_defis_entre_amis` et `20260923142820_defi_entre_amis_message`).
- Champs clés : `id` (fourni par l'appareil : rejouer la création ne crée
  pas de doublon), `creatorId`, `title`, `message` nullable (le mot du
  créateur, 280 points de code au plus), `metric`, `target` nullable
  (« qui en fait le plus »), `durationDays` (3, 7 ou 30), `startsAt`,
  `endsAt` (calculée par le serveur), `status` (`OPEN | CLOSED | CANCELLED`),
  `closedAt`.
- Index : `(creatorId)`, `(status, endsAt)`. Relations : n–1 `User`
  (`Cascade`) ; 1–n `FriendChallengeMember` ; référencé par
  `CommunityReport` (`SetNull`).
- À la suppression d'un compte, dans sa transaction
  (`FriendChallengesRepository.withdrawAccount`) : les défis qu'il a LANCÉS
  sont supprimés ; un défi ÉCHU pas encore réglé dont il est membre est
  d'abord RÉGLÉ avec lui (`dueUnsettledOf`, puis `settle` dans la même
  transaction : rangs figés, `CLOSED`), pour qu'un résultat ne dépende pas
  du jour de la suppression ; puis ses lignes de membre sont retirées de
  tous les autres, et un défi `OPEN` non réglé où plus aucun invité
  n'attend ni ne joue face au créateur passe `CANCELLED` avec `closedAt`
  (la clôture paresseuse, conditionnée à sa nullité, ne le rouvre pas en
  `CLOSED`). Un défi `CANCELLED` ne s'accepte plus (`404` « Ce défi est
  terminé. ») et se range parmi les terminés.

### `FriendChallengeMember`
Un invité (ou le créateur) d'un défi entre amis.
- Clé primaire `(challengeId, userId)`, `status`
  (`INVITED | ACCEPTED | DECLINED | LEFT`), `invitedById`, `contribution`,
  `joinedAt`, `leftAt`, `finalRank` (figé à l'échéance).
- Chaque membre voit le nom, le statut et la contribution de TOUS les
  autres (`friend-challenge.presenter.ts`), qu'ils soient amis entre eux ou
  non.
- Index : `(userId, status)`.

### `LeagueMembership`
La place d'un membre dans la ligue pour UNE semaine (migrations
`20260919225014_ligues` et `20260924120000_ligues_groupes_de_vingt`).
- Clé primaire `(userId, periodKey)` (`periodKey` : semaine ISO),
  `division`, `cohort` (le groupe de 20 dans la division), `score`,
  `finalRank`, `nextDivision`, `settledAt` (règlement de la semaine),
  `createdAt`.
- Index : `(periodKey, division, cohort, score DESC)` (le classement d'un
  groupe), `(userId, periodKey DESC)`.
- La ligne SURVIT à la sortie de la ligue (`joinsLeague = false`) : elle
  compte aux rangs et au règlement, mais le nom n'est plus servi aux autres.
  La suppression d'un compte fait cette même sortie, dans sa transaction ;
  la ligne part à la purge.

---

## Documents liés

- `docs/api/README.md` — enveloppes de réponse, pagination par curseur,
  `x-request-id`.
- `docs/architecture/backend.md` — modules NestJS qui porteront ces domaines.
- `apps/api/prisma/schema.prisma` — état réel du schéma, qui fait foi.
- `infrastructure/database/init/01-init.sql` — `citext` + base `carlys_test`.
