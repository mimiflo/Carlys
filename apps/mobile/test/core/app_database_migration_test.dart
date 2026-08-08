import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Migrations locales 1 → 2 (modèles de séance) puis 2 → 3 (plan
/// synchronisable, pour la reprise multi-appareil).
///
/// Première migration Drift du projet : elle doit être **non destructive**.
/// Une séance en cours au moment de la mise à jour de l'application ne doit
/// rien perdre — c'est la garantie « aucune série saisie n'est jamais perdue »
/// appliquée à la montée de version.

/// Schéma tel qu'il existait en version 1 (Étape 4), plus une séance, une
/// série et une opération de synchronisation déjà en attente.
const List<String> _schemaV1 = [
  '''
  CREATE TABLE local_workout_sessions (
    id TEXT NOT NULL,
    name TEXT NULL,
    notes TEXT NULL,
    status TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER NULL,
    duration_seconds INTEGER NULL,
    sync_status TEXT NOT NULL DEFAULT 'pending',
    PRIMARY KEY (id)
  );
  ''',
  '''
  CREATE TABLE local_workout_sets (
    id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    exercise_id TEXT NULL,
    exercise_name TEXT NOT NULL,
    position INTEGER NOT NULL,
    kind TEXT NOT NULL DEFAULT 'NORMAL',
    reps INTEGER NULL,
    weight_kg REAL NULL,
    duration_seconds INTEGER NULL,
    rest_seconds INTEGER NULL,
    rpe INTEGER NULL,
    completed_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0,
    sync_status TEXT NOT NULL DEFAULT 'pending',
    PRIMARY KEY (id)
  );
  ''',
  '''
  CREATE TABLE sync_operations (
    id TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    operation_type TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_attempt_at INTEGER NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    error TEXT NULL,
    idempotency_key TEXT NOT NULL,
    PRIMARY KEY (id)
  );
  ''',
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
  'PRAGMA user_version = 1;',
];

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final statement in _schemaV1) {
            raw.execute(statement);
          }
        },
      ),
    );
  });

  tearDown(() => db.close());

  test('la montée de version préserve les données de séance déjà saisies',
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

    expect(db.schemaVersion, 3);
  });

  test('les quatre tables des modèles de séance sont créées et utilisables',
      () async {
    expect(await db.select(db.localWorkoutTemplates).get(), isEmpty);
    expect(await db.select(db.localTemplateExercises).get(), isEmpty);
    expect(await db.select(db.localTemplateSets).get(), isEmpty);
    expect(await db.select(db.localSessionPlanItems).get(), isEmpty);
  });

  test('un plan hérité de la version 2 reste « pending », donc protégé',
      () async {
    // Une base v2 a des items de plan sans colonne `sync_status` : la valeur
    // par défaut les met en attente, ce qui interdit au rapatriement de les
    // écraser — la saisie de l'appareil prime toujours.
    await db.into(db.localSessionPlanItems).insert(
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
  });
}
