import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../support/legacy_schemas.dart';

/// Migrations locales 1 → 2 (modèles de séance), 2 → 3 (plan
/// synchronisable, pour la reprise multi-appareil), 3 → 4 (hydratation du
/// jour) puis 4 → 5 (index).
///
/// Chaque test part d'une base **réellement créée avec le schéma d'alors**
/// et la laisse monter jusqu'à la version courante. La règle est la même à
/// chaque palier : la migration doit être **non destructive**. Une séance en
/// cours au moment de la mise à jour de l'application ne doit rien perdre —
/// c'est la garantie « aucune série saisie n'est jamais perdue » appliquée à
/// la montée de version.

/// Une séance, une série et une opération de synchronisation déjà en
/// attente, dans la forme de la version 1.
const List<String> _seedV1 = [
  '''
  INSERT INTO local_workout_sessions
    (id, name, status, started_at, sync_status)
  VALUES ('session-v1', 'Push A', 'IN_PROGRESS', 1786000000, 'pending');
  ''',
  '''
  INSERT INTO local_workout_sets
    (id, session_id, exercise_name, position, kind, reps, weight_kg,
     completed_at, deleted, sync_status)
  VALUES ('set-v1', 'session-v1', 'Développé couché', 0, 'NORMAL', 8, 70.0,
          1786000600, 0, 'pending');
  ''',
  '''
  INSERT INTO sync_operations
    (id, entity_type, entity_id, operation_type, payload, created_at,
     idempotency_key)
  VALUES ('op-v1', 'session', 'session-v1', 'session.create',
          '{}', 1786000000, 'session-v1');
  ''',
];

/// Les index attendus en version courante — le nom est l'identité de
/// l'index côté SQLite, c'est lui que la migration doit produire.
const Set<String> _expectedIndexes = {
  'idx_local_workout_sessions_status_started_at',
  'idx_local_workout_sets_session_id',
  'idx_local_session_plan_items_session_id',
  'idx_sync_operations_status_created_at',
};

/// Index réellement présents dans la base ouverte.
Future<Set<String>> indexNamesOf(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

/// Plan d'exécution de SQLite pour [sql], sur une seule ligne.
Future<String> queryPlanOf(AppDatabase db, String sql) async {
  final rows = await db.customSelect('EXPLAIN QUERY PLAN $sql').get();
  return rows.map((row) => row.read<String>('detail')).join('\n');
}

void main() {
  group('depuis la version 1', () {
    late AppDatabase db;

    setUp(() {
      db = openLegacyDatabase(legacySchemaV1, seed: _seedV1);
    });

    tearDown(() => db.close());

    test(
      'la montée de version préserve les données de séance déjà saisies',
      () async {
        // La première requête déclenche `onUpgrade`.
        final sessions = await db.select(db.localWorkoutSessions).get();
        expect(sessions, hasLength(1));
        expect(sessions.single.id, 'session-v1');
        expect(sessions.single.name, 'Push A');
        expect(sessions.single.status, WorkoutStatus.inProgress.apiValue);
        // Les colonnes ajoutées sont nulles : la séance existante est libre.
        expect(sessions.single.templateId, isNull);
        expect(sessions.single.templateName, isNull);

        final sets = await db.select(db.localWorkoutSets).get();
        expect(sets, hasLength(1));
        expect(sets.single.exerciseName, 'Développé couché');
        expect(sets.single.reps, 8);
        expect(sets.single.weightKg, 70);
        expect(sets.single.plannedReps, isNull);
        expect(sets.single.plannedWeightKg, isNull);

        // La file en attente survit : rien n'est perdu ni renvoyé en double.
        final operations = await db.select(db.syncOperations).get();
        expect(operations, hasLength(1));
        expect(operations.single.operationType, 'session.create');
        // Le compteur d'erreurs serveur (v5) démarre à zéro : l'opération
        // héritée repart avec toutes ses chances.
        expect(operations.single.serverErrorCount, 0);

        // La table d'hydratation, arrivée en version 4, est là et utilisable :
        // une migration qui crée une table sans qu'on puisse y écrire ne vaut
        // rien, et le compteur du jour serait muet au premier verre.
        await db
            .into(db.localWaterIntakes)
            .insert(
              LocalWaterIntakesCompanion.insert(
                day: DateTime(2026, 9, 1),
                milliliters: const Value(750),
                updatedAt: DateTime(2026, 9, 1, 10),
              ),
            );
        final water = await db.select(db.localWaterIntakes).getSingle();
        expect(water.milliliters, 750);

        expect(await indexNamesOf(db), containsAll(_expectedIndexes));
        expect(db.schemaVersion, 5);
      },
    );

    test(
      'les quatre tables des modèles de séance sont créées et utilisables',
      () async {
        expect(await db.select(db.localWorkoutTemplates).get(), isEmpty);
        expect(await db.select(db.localTemplateExercises).get(), isEmpty);
        expect(await db.select(db.localTemplateSets).get(), isEmpty);
        expect(await db.select(db.localSessionPlanItems).get(), isEmpty);
      },
    );

    test(
      'un plan hérité de la version 2 reste « pending », donc protégé',
      () async {
        // Une base v2 a des items de plan sans colonne `sync_status` : la
        // valeur par défaut les met en attente, ce qui interdit au
        // rapatriement de les écraser — la saisie de l'appareil prime
        // toujours.
        await db
            .into(db.localSessionPlanItems)
            .insert(
              LocalSessionPlanItemsCompanion.insert(
                id: 'plan-1',
                sessionId: 'session-v1',
                exercisePosition: 0,
                exerciseName: 'Développé couché',
                setPosition: 0,
              ),
            );
        final items = await db.select(db.localSessionPlanItems).get();
        expect(items.single.syncStatus, 'pending');
      },
    );
  });

  group('depuis la version 4', () {
    late AppDatabase db;

    setUp(() {
      db = openLegacyDatabase(
        legacySchemaV4,
        seed: [
          ..._seedV1,
          // Un plan déjà acquitté et un verre déjà bu : la dernière version
          // sans index avait tout ça, et ne doit rien en perdre.
          '''
          INSERT INTO local_session_plan_items
            (id, session_id, exercise_position, exercise_name, set_position,
             kind, target_reps, skipped, sync_status)
          VALUES ('plan-v4', 'session-v1', 0, 'Développé couché', 0,
                  'NORMAL', 8, 0, 'synced');
          ''',
          '''
          INSERT INTO local_water_intakes (day, milliliters, updated_at)
          VALUES (1786000000, 500, 1786000000);
          ''',
        ],
      );
    });

    tearDown(() => db.close());

    test('les index sont créés sans toucher aux données', () async {
      final sessions = await db.select(db.localWorkoutSessions).get();
      expect(sessions.single.name, 'Push A');

      expect(await indexNamesOf(db), containsAll(_expectedIndexes));

      final plan = await db.select(db.localSessionPlanItems).get();
      expect(plan.single.syncStatus, 'synced');
      final water = await db.select(db.localWaterIntakes).get();
      expect(water.single.milliliters, 500);
      final operation = await db.select(db.syncOperations).getSingle();
      expect(operation.status, 'pending');
      expect(operation.serverErrorCount, 0);
      expect(await db.select(db.localWorkoutSets).get(), hasLength(1));
      expect(db.schemaVersion, 5);
    });

    test('les index servent réellement aux requêtes du moteur', () async {
      // Le plan d'exécution de SQLite nomme l'index utilisé : c'est la seule
      // preuve que l'index correspond à la forme réelle de la requête, et
      // pas seulement qu'il existe.
      expect(
        await queryPlanOf(
          db,
          "SELECT * FROM sync_operations WHERE status = 'pending' "
          'ORDER BY created_at',
        ),
        contains('idx_sync_operations_status_created_at'),
      );
      expect(
        await queryPlanOf(
          db,
          "SELECT * FROM local_workout_sessions WHERE status = 'IN_PROGRESS'",
        ),
        contains('idx_local_workout_sessions_status_started_at'),
      );
      expect(
        await queryPlanOf(
          db,
          "SELECT * FROM local_workout_sets WHERE session_id = 'session-v1'",
        ),
        contains('idx_local_workout_sets_session_id'),
      );
    });
  });
}
