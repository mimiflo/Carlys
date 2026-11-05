import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/data/datasources/workout_session_remote_data_source.dart';
import 'package:carlys_mobile/features/workout_session/data/dto/workout_session_dtos.dart';
import 'package:carlys_mobile/features/workout_session/data/local/workout_conflict_actions.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_sync_api.dart';

/// Le serveur d'un autre appareil : une séance, servie telle quelle.
class _Remote implements WorkoutSessionRemoteDataSource {
  _Remote(this.session);

  final RemoteWorkoutSession session;

  @override
  Future<WorkoutSessionsPage> list({String? cursor, int? limit}) async =>
      WorkoutSessionsPage(
        items: [
          RemoteWorkoutSessionRef(
            id: session.id,
            startedAt: session.startedAt,
            revision: session.revision,
          ),
        ],
        hasMore: false,
      );

  @override
  Future<RemoteWorkoutSession> detail(String sessionId) async => session;
}

/// **Effort perçu de la séance** : donné au bilan, APRÈS la clôture, hors
/// ligne compris — par la file de synchronisation existante, sur la voie
/// de la séance.
void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late SyncEngine engine;
  late WorkoutRepositoryImpl repository;
  late DateTime clock;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    clock = DateTime.utc(2026, 11, 3, 10);
    engine = SyncEngine(database: db, api: api, now: () => clock);
    repository = WorkoutRepositoryImpl(database: db, syncEngine: engine);
  });

  tearDown(() => db.close());

  Future<String> closedSessionOffline() async {
    api.networkDown = true;
    final sessionId = await repository.startWorkout(name: 'Push A');
    await repository.addSet(
      AddSetInput(sessionId: sessionId, exerciseName: 'Pompes', reps: 10),
    );
    await repository.completeWorkout(sessionId);
    return sessionId;
  }

  Future<LocalWorkoutSession> row(String id) => (db.select(
    db.localWorkoutSessions,
  )..where((session) => session.id.equals(id))).getSingle();

  test('hors ligne après la clôture : visible tout de suite, envoyé en '
      'dernier, une seule fois même si on change d’avis', () async {
    final sessionId = await closedSessionOffline();

    await repository.ratePerceivedEffort(sessionId, 7);
    await repository.ratePerceivedEffort(sessionId, 5);

    final detail = await repository.workoutDetail(sessionId);
    expect(detail!.session.perceivedEffort, 5);
    expect(detail.session.syncState, LocalSyncState.pending);
    final updates = (await db.select(db.syncOperations).get()).where(
      (op) => op.operationType == 'session.update',
    );
    expect(updates, hasLength(1), reason: 'La seconde remplace la première.');

    api.networkDown = false;
    clock = clock.add(const Duration(minutes: 10));
    await engine.syncNow();

    // Sur la voie de la séance : création, série, clôture, PUIS l'effort.
    expect(api.log.first, 'session.create:$sessionId');
    expect(api.log.last, 'session.update:$sessionId:{"perceivedEffort":5}');
    expect((await row(sessionId)).syncStatus, 'synced');
  });

  test('retirer l’effort envoie null', () async {
    final sessionId = await closedSessionOffline();
    api.networkDown = false;
    await engine.syncNow();

    await repository.ratePerceivedEffort(sessionId, null);
    clock = clock.add(const Duration(minutes: 10));
    await engine.syncNow();

    expect((await row(sessionId)).perceivedEffort, isNull);
    expect(api.log.last, 'session.update:$sessionId:{"perceivedEffort":null}');
  });

  // La clôture refusée (`failed`) ne retient PAS sa voie : l'effort part,
  // et son succès marquait la séance `synced`. La carte « Réessayer »
  // disparaissait, puis le rapatriement réécrivait la séance EN COURS.
  for (final refus in ['failed', 'conflict']) {
    test('clôture en $refus : l’effort parti, la séance le reste', () async {
      final sessionId = await closedSessionOffline();
      api.networkDown = false;
      await (db.update(db.syncOperations)
            ..where((op) => op.operationType.equals('session.complete')))
          .write(SyncOperationsCompanion(status: Value(refus)));
      await engine.syncNow();
      await (db.update(db.localWorkoutSessions)
            ..where((session) => session.id.equals(sessionId)))
          .write(LocalWorkoutSessionsCompanion(syncStatus: Value(refus)));

      await repository.ratePerceivedEffort(sessionId, 9);
      expect((await row(sessionId)).syncStatus, refus);
      clock = clock.add(const Duration(minutes: 10));
      await engine.syncNow();

      final session = await row(sessionId);
      expect(session.perceivedEffort, 9);
      expect(session.syncStatus, refus, reason: 'sa carte en dépend');
      final ops = await db.select(db.syncOperations).get();
      expect(ops.map((op) => op.operationType), contains('session.complete'));
    });
  }

  test('envoi en vol : son succès ne marque pas synced l’évaluation qui '
      'l’a remplacé', () async {
    final sessionId = await closedSessionOffline();
    api.networkDown = false;
    await engine.syncNow();
    await repository.ratePerceivedEffort(sessionId, 7);

    // Le PATCH de 7 est en vol quand on choisit 9. Au départ du PATCH de 9,
    // on relève l'état de la séance : le succès de 7 ne devait pas la
    // marquer `synced`, 9 n'était pas encore parti.
    var calls = 0;
    String? statusWhileNineInFlight;
    api.beforeCall = () async {
      calls++;
      if (calls == 1) {
        await repository.ratePerceivedEffort(sessionId, 9);
      } else {
        statusWhileNineInFlight = (await row(sessionId)).syncStatus;
      }
    };
    clock = clock.add(const Duration(minutes: 10));
    await engine.syncNow();
    if (calls < 2) {
      clock = clock.add(const Duration(minutes: 10));
      await engine.syncNow();
    }
    api.beforeCall = null;

    expect(statusWhileNineInFlight, 'pending');
    expect(api.log.last, 'session.update:$sessionId:{"perceivedEffort":9}');
    expect((await row(sessionId)).syncStatus, 'synced');
  });

  test('une ancienne évaluation refusée ne revient pas écraser la '
      'nouvelle', () async {
    final sessionId = await closedSessionOffline();
    api.networkDown = false;
    await engine.syncNow();
    api.rejectedIds.add(sessionId);
    await repository.ratePerceivedEffort(sessionId, 3);
    clock = clock.add(const Duration(minutes: 10));
    await engine.syncNow();
    api.rejectedIds.clear();

    await repository.ratePerceivedEffort(sessionId, 8);
    await engine.retryRejected();
    clock = clock.add(const Duration(minutes: 10));
    await engine.syncNow();

    final updates = api.log.where((l) => l.startsWith('session.update'));
    expect(updates, ['session.update:$sessionId:{"perceivedEffort":8}']);
    expect(await db.select(db.syncOperations).get(), isEmpty);
  });

  test('séance inconnue ou valeur hors échelle : rien en file', () async {
    await repository.ratePerceivedEffort('inconnue', 5);
    expect(await db.select(db.syncOperations).get(), isEmpty);

    final sessionId = await closedSessionOffline();
    expect(
      () => repository.ratePerceivedEffort(sessionId, 11),
      throwsRangeError,
    );
  });

  test('le rapatriement rend l’effort donné sur un autre appareil', () async {
    final remote = RemoteWorkoutSession(
      id: 'session-ailleurs',
      status: 'COMPLETED',
      startedAt: DateTime.utc(2026, 11, 2, 17),
      endedAt: DateTime.utc(2026, 11, 2, 18),
      perceivedEffort: 7,
      revision: 3,
      sets: const [],
      plan: const [],
    );
    final restoring = WorkoutRepositoryImpl(
      database: db,
      syncEngine: engine,
      remote: _Remote(remote),
    );

    await restoring.restoreSessions();

    expect((await row('session-ailleurs')).perceivedEffort, 7);
  });

  test('« Prendre la version du serveur » garde l’effort encore en file, '
      'qui part ensuite', () async {
    final sessionId = await closedSessionOffline();
    await repository.ratePerceivedEffort(sessionId, 8);
    final serveur = RemoteWorkoutSession(
      id: sessionId,
      status: 'ABANDONED',
      startedAt: DateTime.utc(2026, 11, 3, 9),
      endedAt: DateTime.utc(2026, 11, 3, 9, 30),
      revision: 5,
      sets: const [],
      plan: const [],
    );

    await WorkoutConflictActions(
      database: db,
      remote: _Remote(serveur),
    ).takeServer(sessionId);

    final session = await row(sessionId);
    expect(session.status, 'ABANDONED', reason: 'la version du serveur');
    expect(session.perceivedEffort, 8, reason: 'pas encore reçu là-bas');
    expect(session.syncStatus, 'pending');

    api.networkDown = false;
    clock = clock.add(const Duration(minutes: 10));
    await engine.syncNow();
    expect(api.log.last, 'session.update:$sessionId:{"perceivedEffort":8}');
  });

  test('le DTO lit l’effort, et son absence (serveur plus ancien)', () {
    final base = {
      'id': 's',
      'status': 'COMPLETED',
      'startedAt': '2026-11-02T17:00:00.000Z',
    };
    expect(sessionFromJson({...base, 'perceivedEffort': 4}).perceivedEffort, 4);
    expect(sessionFromJson(base).perceivedEffort, isNull);
  });
}
