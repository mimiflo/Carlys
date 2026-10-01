import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_sync_api.dart';

/// « PRÉCÉDENT … » sous chaque exercice de la séance en cours : la dernière
/// série chargée de cet exercice, dans les séances closes récentes. Lue en
/// UNE requête ; elle relisait chaque séance entière, une à une.
void main() {
  late AppDatabase db;
  late WorkoutRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = WorkoutRepositoryImpl(
      database: db,
      syncEngine: SyncEngine(database: db, api: FakeSyncApi()),
    );
  });

  tearDown(() => db.close());

  /// Une séance close le [jour] de septembre : `startWorkout` date de
  /// maintenant, à la seconde, et deux séances d'une même seconde seraient
  /// sans ordre.
  Future<void> seance(int jour, List<(String, int?, double?)> series) async {
    final id = await repository.startWorkout();
    for (final (exercice, reps, kg) in series) {
      await repository.addSet(
        AddSetInput(
          sessionId: id,
          exerciseName: exercice,
          reps: reps,
          weightKg: kg,
        ),
      );
    }
    await repository.completeWorkout(id);
    await (db.update(
      db.localWorkoutSessions,
    )..where((row) => row.id.equals(id))).write(
      LocalWorkoutSessionsCompanion(
        startedAt: Value(DateTime.utc(2026, 9, jour)),
      ),
    );
  }

  Future<WorkoutSetEntry?> precedent(String exercice, {int lookback = 8}) =>
      repository.previousPerformance(exercice, lookback: lookback);

  test(
    'la dernière série chargée de la séance close la plus récente',
    () async {
      await seance(1, [('Squat', 5, 100), ('Squat', 5, 105)]);
      await seance(2, [
        ('Squat', 8, 90),
        ('Squat', 6, 95),
        ('Squat', 10, null),
      ]);

      final set = await precedent('Squat');
      // Série sans charge ignorée ; séance la plus récente d'abord.
      expect((set?.reps, set?.weightKg), (6, 95));
    },
  );

  test('une série supprimée ne compte pas', () async {
    await seance(1, [('Squat', 5, 100), ('Squat', 5, 105)]);
    final derniere = await precedent('Squat');
    await repository.deleteSet(derniere!.id);

    expect((await precedent('Squat'))?.weightKg, 100);
  });

  test('ni la séance en cours, ni au-delà du nombre inspecté', () async {
    await seance(1, [('Squat', 5, 100)]);
    await seance(2, [('Tractions', 8, 0)]);
    final enCours = await repository.startWorkout();
    await repository.addSet(
      AddSetInput(
        sessionId: enCours,
        exerciseName: 'Squat',
        reps: 3,
        weightKg: 120,
      ),
    );

    expect((await precedent('Squat'))?.weightKg, 100);
    expect(await precedent('Squat', lookback: 1), isNull);
    expect(await precedent('Développé couché'), isNull);
  });
}
