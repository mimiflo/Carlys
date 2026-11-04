import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/data/datasources/workout_session_remote_data_source.dart';
import 'package:carlys_mobile/features/workout_session/data/dto/workout_session_dtos.dart';
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

  test('une séance en conflit le reste : sa carte en dépend', () async {
    final sessionId = await closedSessionOffline();
    await (db.update(
      db.localWorkoutSessions,
    )..where((session) => session.id.equals(sessionId))).write(
      const LocalWorkoutSessionsCompanion(syncStatus: Value('conflict')),
    );

    await repository.ratePerceivedEffort(sessionId, 9);

    final session = await row(sessionId);
    expect(session.perceivedEffort, 9);
    expect(session.syncStatus, 'conflict');
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
