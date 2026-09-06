import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Hydratation du jour — UNE ligne par journée vécue.
///
/// Volontairement LOCALE et non synchronisée, contrairement au journal
/// alimentaire ou aux mesures corporelles. Trois raisons : le compteur se
/// remet à zéro chaque nuit et ne porte aucun historique qu'on voudrait
/// consulter ailleurs ; le geste est un tapotement répété qu'un aller-retour
/// réseau rendrait poussif ; et boire relève de la journée en cours, pas d'un
/// dossier. Le jour où l'on voudra l'historiser côté serveur, cette table
/// deviendra le cache local d'une ressource, sans rien changer à l'écran.
class LocalWaterIntakes extends Table {
  /// Minuit LOCAL du jour concerné — l'hydratation se compte par journée
  /// vécue, pas en UTC : boire à 23 h compte pour aujourd'hui.
  DateTimeColumn get day => dateTime()();

  /// Total bu, en millilitres. Jamais négatif (le dépôt le borne).
  IntColumn get milliliters => integer().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

/// Séance locale — source de vérité immédiate de l'application.
///
/// Index `(status, started_at)` : la séance en cours, l'historique et la règle
/// « au plus une séance active » filtrent toutes par statut, et l'historique
/// se lit par date de début décroissante — sans lui, chaque émission du flux
/// parcourait la table entière.
@TableIndex(
  name: 'idx_local_workout_sessions_status_started_at',
  columns: {#status, #startedAt},
)
class LocalWorkoutSessions extends Table {
  /// UUID généré sur l'appareil, partagé avec le serveur.
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// IN_PROGRESS | COMPLETED | ABANDONED (valeurs API).
  TextColumn get status => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationSeconds => integer().nullable()();

  /// Modèle de séance lancé, s'il y en a un (UUID appareil).
  TextColumn get templateId => text().nullable()();

  /// Nom du modèle AU MOMENT DU LANCEMENT — dénormalisé, immuable : la
  /// provenance reste lisible même si le modèle est renommé ou supprimé.
  TextColumn get templateName => text().nullable()();

  /// pending | synced | failed.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Série locale (append-only : jamais perdue, suppression logique).
///
/// Index `session_id` : toutes les lectures de séries partent d'une séance
/// (jointures de l'historique et du détail, position de la prochaine série,
/// garde-fou du rapatriement).
@TableIndex(name: 'idx_local_workout_sets_session_id', columns: {#sessionId})
class LocalWorkoutSets extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get exerciseId => text().nullable()();
  TextColumn get exerciseName => text()();
  IntColumn get position => integer()();

  /// WARMUP | NORMAL | DROP (valeurs API).
  TextColumn get kind => text().withDefault(const Constant('NORMAL'))();
  IntColumn get reps => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  IntColumn get restSeconds => integer().nullable()();
  IntColumn get rpe => integer().nullable()();

  /// Cible AFFICHÉE au moment où l'utilisateur a validé la série (null hors
  /// modèle). Fait historique : jamais réécrit après coup.
  IntColumn get plannedReps => integer().nullable()();
  RealColumn get plannedWeightKg => real().nullable()();
  DateTimeColumn get completedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Modèle de séance local — document PRESCRIPTIF réutilisable.
///
/// Le contenu (lignes d'exercice et séries prévues) est physiquement réécrit
/// à chaque enregistrement, en miroir exact du `PUT` serveur ; le modèle
/// lui-même porte un tombstone (`deleted`) jusqu'à l'acquittement.
class LocalWorkoutTemplates extends Table {
  /// UUID généré sur l'appareil, partagé avec le serveur.
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get estimatedDurationMinutes => integer().nullable()();

  /// Dernier lancement — miroir local de la valeur serveur.
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Ligne d'exercice d'un modèle, ordonnée par [position] (contiguë depuis 0).
class LocalTemplateExercises extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text()();
  TextColumn get exerciseId => text().nullable()();

  /// Dénormalisé : le modèle survit aux évolutions du catalogue.
  TextColumn get exerciseName => text()();
  IntColumn get position => integer()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Série PRÉVUE d'une ligne d'exercice : des cibles, pas des mesures.
class LocalTemplateSets extends Table {
  TextColumn get id => text()();
  TextColumn get templateExerciseId => text()();
  IntColumn get position => integer()();

  /// WARMUP | NORMAL | DROP (valeurs API).
  TextColumn get kind => text().withDefault(const Constant('NORMAL'))();
  IntColumn get targetReps => integer().nullable()();
  RealColumn get targetWeightKg => real().nullable()();
  IntColumn get restSeconds => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Plan de la séance en cours — copie APLATIE du modèle au lancement :
/// une ligne par série prévue, c'est la forme dont l'écran a besoin
/// (« série 2 sur 4 »).
///
/// Synchronisé, mais pas comme une saisie ordinaire : le plan part EN BLOC
/// avec `session.create`, ses appariements voyagent avec la série qui les
/// honore, et seuls les « passer » ont leur propre opération. C'est ce qui
/// permet de reprendre sur un autre appareil une séance commencée ailleurs
/// (docs/product/workout-templates.md, D5).
///
/// Index `session_id` : le plan se lit, s'acquitte et se purge toujours par
/// séance, et la table grossit avec l'historique rapatrié.
@TableIndex(
  name: 'idx_local_session_plan_items_session_id',
  columns: {#sessionId},
)
class LocalSessionPlanItems extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  IntColumn get exercisePosition => integer()();
  TextColumn get exerciseId => text().nullable()();
  TextColumn get exerciseName => text()();

  /// Rang de la série DANS l'exercice, à partir de 0.
  IntColumn get setPosition => integer()();
  TextColumn get kind => text().withDefault(const Constant('NORMAL'))();
  IntColumn get targetReps => integer().nullable()();
  RealColumn get targetWeightKg => real().nullable()();
  IntColumn get restSeconds => integer().nullable()();

  /// Série réalisée qui a honoré cet item, sinon null.
  TextColumn get doneSetId => text().nullable()();
  BoolColumn get skipped => boolean().withDefault(const Constant(false))();

  /// pending | synced | failed — état de l'item VIS-À-VIS DU SERVEUR.
  ///
  /// Le rapatriement s'en sert comme garde-fou : il ne réécrit jamais un plan
  /// dont une modification locale n'a pas encore été acquittée, sinon un
  /// « passer » fait hors ligne serait effacé par un état serveur plus ancien.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// File d'opérations de synchronisation (docs/synchronization/offline-first.md).
///
/// Index `(status, created_at)` : le drainage lit les opérations par statut,
/// dans l'ordre d'écriture — exactement la forme de cet index.
@TableIndex(
  name: 'idx_sync_operations_status_created_at',
  columns: {#status, #createdAt},
)
class SyncOperations extends Table {
  TextColumn get id => text()();

  /// session | set | template | plan.
  TextColumn get entityType => text()();

  /// Identifiant visé par l'opération. Pour `plan.skip`, c'est la SÉANCE :
  /// une opération porte la liste des prévisions passées, pas une seule.
  TextColumn get entityId => text()();

  /// session.create | session.complete | session.abandon | set.upsert |
  /// set.delete | plan.skip | template.save | template.delete.
  TextColumn get operationType => text()();

  /// Corps JSON de la requête à rejouer.
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// Toutes les tentatives, réseau compris : c'est le compteur du backoff.
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// Réponses 5xx d'affilée pour CETTE opération. Une coupure réseau
  /// n'y compte pas : elle frappe toute la file, pas une opération. Au-delà
  /// de `SyncEngine.serverAttemptsMax`, l'opération est mise de côté
  /// (`exhausted`) pour ne plus retenir les opérations indépendantes.
  IntColumn get serverErrorCount => integer().withDefault(const Constant(0))();

  /// pending | failed | exhausted (une opération réussie est supprimée).
  ///
  /// `failed` : refus définitif du serveur (4xx), jamais rejoué
  /// automatiquement. `exhausted` : trop d'erreurs serveur d'affilée,
  /// rejouée à la prochaine ouverture de l'application.
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get error => text().nullable()();

  /// L'id de l'entité EST la clé d'idempotence côté serveur.
  TextColumn get idempotencyKey => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    LocalWorkoutSessions,
    LocalWorkoutSets,
    LocalWorkoutTemplates,
    LocalTemplateExercises,
    LocalTemplateSets,
    LocalSessionPlanItems,
    LocalWaterIntakes,
    SyncOperations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Historique des versions du schéma local :
  ///  - **1** — séances, séries, file de synchronisation (Étape 4) ;
  ///  - **2** — modèles de séance : quatre tables ajoutées, `templateId` /
  ///    `templateName` sur les séances, `plannedReps` / `plannedWeightKg` sur
  ///    les séries ;
  ///  - **3** — reprise multi-appareil : `syncStatus` sur les items de plan,
  ///    qui deviennent synchronisables ;
  ///  - **4** — hydratation : une table locale du total quotidien ;
  ///  - **5** — index sur les colonnes que les requêtes réelles filtrent
  ///    (statut + date des séances, séries et plan par séance, file par
  ///    statut et ordre d'écriture) ; `serverErrorCount` sur la file, pour le
  ///    plafond de tentatives.
  @override
  int get schemaVersion => 5;

  /// Migration locale : les colonnes ajoutées sont toutes **nullables** et les
  /// index se créent à côté des données, donc la montée de version ne réécrit
  /// ni ne perd aucune donnée déjà saisie — une séance en cours au moment de
  /// la mise à jour reste intacte.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(localWorkoutTemplates);
        await migrator.createTable(localTemplateExercises);
        await migrator.createTable(localTemplateSets);
        await migrator.createTable(localSessionPlanItems);
        await migrator.addColumn(
          localWorkoutSessions,
          localWorkoutSessions.templateId,
        );
        await migrator.addColumn(
          localWorkoutSessions,
          localWorkoutSessions.templateName,
        );
        await migrator.addColumn(
          localWorkoutSets,
          localWorkoutSets.plannedReps,
        );
        await migrator.addColumn(
          localWorkoutSets,
          localWorkoutSets.plannedWeightKg,
        );
      }
      // `from < 2` a créé la table avec sa définition ACTUELLE, colonne
      // comprise : seule une base réellement en version 2 est à compléter.
      if (from == 2) {
        await migrator.addColumn(
          localSessionPlanItems,
          localSessionPlanItems.syncStatus,
        );
        // Un plan déjà local n'a jamais été transmis : il reste donc
        // `pending` (valeur par défaut de la colonne), ce qui met le
        // rapatriement en retrait sur cette séance — le bon réflexe, la
        // saisie de l'appareil ne peut pas être écrasée.
      }
      if (from < 4) {
        // Table neuve : rien à reprendre, l'hydratation commence
        // aujourd'hui. Aucune donnée existante n'est touchée.
        await migrator.createTable(localWaterIntakes);
      }
      if (from < 5) {
        // Compteur à zéro pour les opérations déjà en file : elles repartent
        // avec toutes leurs chances.
        await migrator.addColumn(
          syncOperations,
          syncOperations.serverErrorCount,
        );
        // Un index ne touche pas aux lignes : SQLite le construit à côté
        // des données existantes, qui restent intactes.
        await migrator.createIndex(idxLocalWorkoutSessionsStatusStartedAt);
        await migrator.createIndex(idxLocalWorkoutSetsSessionId);
        await migrator.createIndex(idxLocalSessionPlanItemsSessionId);
        await migrator.createIndex(idxSyncOperationsStatusCreatedAt);
      }
    },
  );
}

/// Connexion sur fichier, ouverte paresseusement dans un isolate dédié.
QueryExecutor openAppDatabaseConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    return NativeDatabase.createInBackground(
      File(p.join(directory.path, 'carlys.sqlite')),
    );
  });
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(openAppDatabaseConnection());
  ref.onDispose(database.close);
  return database;
});
