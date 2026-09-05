import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_sync_api.dart';

/// Parcours critiques offline-first :
/// séance hors ligne → récupération de connexion → synchronisation ordonnée,
/// backoff, rejet serveur, suppression, idempotence côté client.
void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late SyncEngine engine;
  late WorkoutRepositoryImpl repository;
  late DateTime clock;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    clock = DateTime.utc(2026, 8, 7, 10);
    engine = SyncEngine(database: db, api: api, now: () => clock);
    repository = WorkoutRepositoryImpl(database: db, syncEngine: engine);
  });

  tearDown(() => db.close());

  Future<int> pendingOperations() async =>
      (await db.select(db.syncOperations).get())
          .where((op) => op.status == 'pending')
          .length;

  test('séance complète hors ligne : rien n’est perdu, puis la synchronisation '
      'rejoue tout dans l’ordre au retour du réseau', () async {
    api.networkDown = true;

    final sessionId = await repository.startWorkout(name: 'Push A');
    await repository.addSet(
      AddSetInput(
        sessionId: sessionId,
        exerciseName: 'Pompes',
        reps: 10,
        weightKg: 20,
        restSeconds: 90,
      ),
    );
    await repository.addSet(
      AddSetInput(
        sessionId: sessionId,
        exerciseName: 'Pompes',
        reps: 8,
        weightKg: 20,
      ),
    );

    // Tout est immédiatement disponible localement, marqué en attente.
    final active = await repository.watchActiveWorkout().first;
    expect(active, isNotNull);
    expect(active!.sets, hasLength(2));
    expect(active.sets.first.syncState, LocalSyncState.pending);
    expect(active.sets[1].position, 1);

    await repository.completeWorkout(sessionId);

    final history = await repository.watchHistory().first;
    expect(history, hasLength(1));
    expect(history.first.setsCount, 2);
    expect(history.first.totalVolumeKg, 10 * 20 + 8 * 20);
    expect(await pendingOperations(), 4);
    expect(api.log, isEmpty);

    // Retour du réseau (au-delà du backoff) : la file se vide, EN ORDRE.
    api.networkDown = false;
    clock = clock.add(const Duration(minutes: 10));
    await engine.syncNow();

    expect(api.log, hasLength(4));
    expect(api.log.first, 'session.create:$sessionId');
    expect(api.log[1], startsWith('set.upsert:'));
    expect(api.log[2], startsWith('set.upsert:'));
    expect(api.log.last, 'session.complete:$sessionId');
    expect(await pendingOperations(), 0);

    final detail = await repository.workoutDetail(sessionId);
    expect(detail!.session.syncState, LocalSyncState.synced);
    expect(
      detail.sets.every((set) => set.syncState == LocalSyncState.synced),
      isTrue,
    );

    // Rejouer la synchronisation n'envoie rien de plus (opérations purgées).
    await engine.syncNow();
    expect(api.log, hasLength(4));
  });

  test('backoff exponentiel : pas de nouvel essai avant le délai', () async {
    api.networkDown = true;
    await repository.startWorkout();
    // Rejoint le poke opportuniste (fire-and-forget) : après cet await,
    // la première tentative a eu lieu, déterministe.
    await engine.syncNow();

    Future<int> attemptsOfFirstOp() async =>
        (await db.select(db.syncOperations).get()).first.attemptCount;

    // Le démarrage a déjà tenté une fois.
    expect(await attemptsOfFirstOp(), 1);

    await engine.syncNow(); // trop tôt (backoff 5 s)
    expect(await attemptsOfFirstOp(), 1);

    clock = clock.add(const Duration(seconds: 6));
    await engine.syncNow();
    expect(await attemptsOfFirstOp(), 2);

    clock = clock.add(const Duration(seconds: 6)); // backoff passé à 10 s
    await engine.syncNow();
    expect(await attemptsOfFirstOp(), 2);
  });

  test(
    'un refus serveur (4xx) marque l’opération en échec sans bloquer la file',
    () async {
      // Hors ligne pendant la préparation : la file s'accumule, la rejection
      // est configurée AVANT toute livraison (déterministe face aux pokes).
      api.networkDown = true;
      final sessionId = await repository.startWorkout();
      await repository.addSet(
        AddSetInput(sessionId: sessionId, exerciseName: 'Rejetée', reps: 5),
      );
      await repository.addSet(
        AddSetInput(sessionId: sessionId, exerciseName: 'Acceptée', reps: 5),
      );

      final active = await repository.watchActiveWorkout().first;
      final rejectedId = active!.sets.first.id;
      api.rejectedIds.add(rejectedId);

      api.networkDown = false;
      clock = clock.add(const Duration(minutes: 10));
      await engine.syncNow();

      // La série refusée est marquée failed, les suivantes sont passées.
      expect(
        api.log.where((entry) => entry.startsWith('set.upsert:')),
        hasLength(1),
      );
      final operations = await db.select(db.syncOperations).get();
      expect(operations.where((op) => op.status == 'failed'), hasLength(1));
      expect(operations.where((op) => op.status == 'pending'), isEmpty);

      final refreshed = await repository.workoutDetail(sessionId);
      final rejectedSet = refreshed!.sets.firstWhere(
        (set) => set.id == rejectedId,
      );
      expect(rejectedSet.syncState, LocalSyncState.failed);
    },
  );

  test(
    'suppression d’une série : disparition locale immédiate + opération de sync',
    () async {
      api.networkDown =
          true; // la file s'accumule, livraison contrôlée plus bas
      final sessionId = await repository.startWorkout();
      await repository.addSet(
        AddSetInput(sessionId: sessionId, exerciseName: 'Pompes', reps: 10),
      );
      final active = await repository.watchActiveWorkout().first;
      final setId = active!.sets.single.id;

      await repository.deleteSet(setId);

      final afterDelete = await repository.watchActiveWorkout().first;
      expect(afterDelete!.sets, isEmpty);

      api.networkDown = false;
      clock = clock.add(const Duration(minutes: 10));
      await engine.syncNow();
      expect(api.log, contains('set.delete:$setId'));
    },
  );

  test(
    'une seule séance active à la fois ; clôture locale idempotente',
    () async {
      api.networkDown = true; // les opérations restent en file, comptables
      final sessionId = await repository.startWorkout();
      await expectLater(repository.startWorkout(), throwsStateError);

      await repository.completeWorkout(sessionId);
      await repository.completeWorkout(sessionId); // rejeu sans effet

      final operations = await db.select(db.syncOperations).get();
      expect(
        operations.where((op) => op.operationType == 'session.complete'),
        hasLength(1),
      );

      // Une nouvelle séance peut démarrer après la clôture.
      final secondId = await repository.startWorkout();
      expect(secondId, isNot(sessionId));
    },
  );
}
