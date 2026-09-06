import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_sync_api.dart';

/// L'historique agrège le nombre de séries et le volume en SQL, sans charger
/// les séries. Ce test le confronte à l'ANCIEN calcul, le pli Dart de
/// [WorkoutWithSets] que le détail de séance utilise toujours : sur le même
/// jeu de données, les deux doivent donner exactement les mêmes nombres.
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

  Future<void> insertSession({
    required String id,
    required String status,
    required DateTime startedAt,
  }) {
    return db
        .into(db.localWorkoutSessions)
        .insert(
          LocalWorkoutSessionsCompanion.insert(
            id: id,
            name: Value(id),
            status: status,
            startedAt: startedAt,
          ),
        );
  }

  Future<void> insertSet({
    required String id,
    required String sessionId,
    required int position,
    int? reps,
    double? weightKg,
    bool deleted = false,
  }) {
    return db
        .into(db.localWorkoutSets)
        .insert(
          LocalWorkoutSetsCompanion.insert(
            id: id,
            sessionId: sessionId,
            exerciseName: 'Développé couché',
            position: position,
            reps: Value(reps),
            weightKg: Value(weightKg),
            completedAt: DateTime.utc(2026, 9, 1),
            deleted: Value(deleted),
          ),
        );
  }

  test(
    'même nombre de séries et même volume que le calcul historique',
    () async {
      // Une séance riche : charges décimales, série sans charge (au poids du
      // corps), série sans répétitions (tenue), série supprimée.
      await insertSession(
        id: 'riche',
        status: 'COMPLETED',
        startedAt: DateTime.utc(2026, 9, 1, 10),
      );
      await insertSet(
        id: 'r-1',
        sessionId: 'riche',
        position: 0,
        reps: 8,
        weightKg: 62.5,
      );
      await insertSet(
        id: 'r-2',
        sessionId: 'riche',
        position: 1,
        reps: 6,
        weightKg: 67.5,
      );
      await insertSet(id: 'r-3', sessionId: 'riche', position: 2, reps: 12);
      await insertSet(id: 'r-4', sessionId: 'riche', position: 3, weightKg: 20);
      await insertSet(
        id: 'r-5',
        sessionId: 'riche',
        position: 4,
        reps: 10,
        weightKg: 100,
        deleted: true,
      );
      // Une séance abandonnée sans aucune série : elle doit figurer, à zéro.
      await insertSession(
        id: 'vide',
        status: 'ABANDONED',
        startedAt: DateTime.utc(2026, 8, 30, 18),
      );
      // Une séance en cours : jamais dans l'historique.
      await insertSession(
        id: 'en-cours',
        status: 'IN_PROGRESS',
        startedAt: DateTime.utc(2026, 9, 2, 8),
      );
      await insertSet(
        id: 'c-1',
        sessionId: 'en-cours',
        position: 0,
        reps: 5,
        weightKg: 50,
      );

      final history = await repository.watchHistory().first;

      expect(history.map((entry) => entry.session.id), ['riche', 'vide']);
      for (final entry in history) {
        final detail = await repository.workoutDetail(entry.session.id);
        expect(entry.setsCount, detail!.setsCount, reason: entry.session.id);
        expect(
          entry.totalVolumeKg,
          closeTo(detail.totalVolumeKg, 1e-9),
          reason: entry.session.id,
        );
      }
      // Les valeurs elles-mêmes, pour lire le test sans calculer de tête.
      expect(history.first.setsCount, 4);
      expect(history.first.totalVolumeKg, closeTo(8 * 62.5 + 6 * 67.5, 1e-9));
      expect(history.last.setsCount, 0);
      expect(history.last.totalVolumeKg, 0);
      expect(history.first.session.name, 'riche');
      expect(history.first.session.status, WorkoutStatus.completed);
    },
  );

  test('le flux se rafraîchit quand une série arrive', () async {
    await insertSession(
      id: 'seance',
      status: 'COMPLETED',
      startedAt: DateTime.utc(2026, 9, 1, 10),
    );
    final emissions = <int>[];
    final subscription = repository.watchHistory().listen(
      (entries) => emissions.add(entries.single.setsCount),
    );
    await pumpEventQueue();
    await insertSet(
      id: 's-1',
      sessionId: 'seance',
      position: 0,
      reps: 8,
      weightKg: 60,
    );
    await pumpEventQueue();
    await subscription.cancel();

    expect(emissions, [0, 1]);
  });
}
