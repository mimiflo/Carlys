import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_sync_api.dart';

/// Les requêtes RÉELLES du dépôt de séances, passées au plan d'exécution de
/// SQLite : aucune ne doit parcourir une table entière qui grossit avec
/// l'historique rapatrié.
///
/// Le piège : `status <> 'IN_PROGRESS'` ne peut pas servir l'index
/// `(status, started_at)` — SQLite ne sait pas chercher une INÉGALITÉ dans
/// un index. Il parcourait donc toutes les séances à chaque émission de
/// l'historique, quand `status IN ('COMPLETED', 'ABANDONED')`, qui dit la
/// même chose (le statut ne prend que trois valeurs), y cherche.
void main() {
  late _Recorder recorder;
  late AppDatabase db;
  late WorkoutRepositoryImpl repository;

  setUp(() {
    recorder = _Recorder();
    db = AppDatabase(NativeDatabase.memory().interceptWith(recorder));
    repository = WorkoutRepositoryImpl(
      database: db,
      syncEngine: SyncEngine(database: db, api: FakeSyncApi()),
    );
  });

  tearDown(() => db.close());

  /// Le plan de chaque requête enregistrée, avec ses vraies valeurs.
  Future<List<String>> plans() async {
    recorder.recording = false;
    final result = <String>[];
    for (final (sql, args) in recorder.statements) {
      final rows = await db
          .customSelect(
            'EXPLAIN QUERY PLAN $sql',
            variables: [for (final arg in args) Variable(arg)],
          )
          .get();
      result.add(
        '$sql\n  → ${rows.map((row) => row.read<String>('detail')).join(' | ')}',
      );
    }
    return result;
  }

  test('historique, précédent et suppression d’une série : aucun parcours '
      'complet des séances ni du plan', () async {
    for (var i = 0; i < 3; i++) {
      final id = await repository.startWorkout();
      await repository.addSet(
        AddSetInput(sessionId: id, exerciseName: 'Squat', reps: 5),
      );
      await repository.completeWorkout(id);
    }
    final active = await repository.startWorkout();
    final setId = await repository.addSet(
      AddSetInput(sessionId: active, exerciseName: 'Squat', reps: 5),
    );

    recorder.recording = true;
    await repository.watchHistory().first;
    await repository.previousPerformance('Squat', lookback: 8);
    await repository.deleteSet(setId);

    final watched = (await plans()).where(
      (plan) =>
          plan.contains('local_workout_sessions') ||
          plan.contains('local_session_plan_items'),
    );
    expect(watched, isNotEmpty);
    expect(
      watched.where(
        (plan) =>
            plan.contains('SCAN local_workout_sessions') ||
            plan.contains('SCAN local_session_plan_items'),
      ),
      isEmpty,
    );
  });
}

/// Retient chaque requête lue ou écrite, et ses valeurs liées.
class _Recorder extends QueryInterceptor {
  bool recording = false;
  final List<(String, List<Object?>)> statements = [];

  void _keep(String statement, List<Object?> args) {
    if (recording) statements.add((statement, args));
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _keep(statement, args);
    return super.runSelect(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _keep(statement, args);
    return super.runUpdate(executor, statement, args);
  }
}
