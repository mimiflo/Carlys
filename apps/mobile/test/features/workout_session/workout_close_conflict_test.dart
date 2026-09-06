import 'dart:convert';

import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/synchronization/sync_conflict_resolver.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/data/datasources/workout_session_remote_data_source.dart';
import 'package:carlys_mobile/features/workout_session/data/dto/workout_session_dtos.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_close_conflict_resolver.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_sync_api.dart';

/// Source distante de test : sert une séance, ou jette ce qu'on lui dit.
class _FakeRemote implements WorkoutSessionRemoteDataSource {
  RemoteWorkoutSession? session;
  AppException? failure;
  int detailCalls = 0;

  @override
  Future<WorkoutSessionsPage> list({String? cursor, int? limit}) async =>
      const WorkoutSessionsPage(items: [], hasMore: false);

  @override
  Future<RemoteWorkoutSession> detail(String sessionId) async {
    detailCalls++;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return session!;
  }
}

RemoteWorkoutSession _serverVersion({
  required String status,
  List<RemoteWorkoutSet> sets = const [],
}) => RemoteWorkoutSession(
  id: 'seance',
  name: 'Push force',
  status: status,
  startedAt: DateTime.utc(2026, 9, 1, 17),
  endedAt: DateTime.utc(2026, 9, 1, 18),
  durationSeconds: 3600,
  sets: sets,
  plan: const [],
);

/// Le résolveur lit la version serveur pour distinguer la course (même
/// issue) du vrai désaccord ; les deux gestes de l'utilisateur ferment le
/// conflit sans perdre une série.
void main() {
  late AppDatabase db;
  late _FakeRemote remote;
  late FakeSyncApi api;
  late DateTime clock;
  late SyncEngine engine;
  late WorkoutRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = _FakeRemote();
    api = FakeSyncApi();
    clock = DateTime.utc(2026, 9, 1, 19);
    engine = SyncEngine(
      database: db,
      api: api,
      conflictResolver: WorkoutCloseConflictResolver(
        database: db,
        remote: remote,
      ),
      now: () => clock,
    );
    repository = WorkoutRepositoryImpl(
      database: db,
      syncEngine: engine,
      remote: remote,
    );
  });

  tearDown(() => db.close());

  /// Une séance terminée ICI, avec une série acquittée et une autre encore
  /// en attente, dont la clôture est en file.
  Future<void> seedLocalCompletion() async {
    await db
        .into(db.localWorkoutSessions)
        .insert(
          LocalWorkoutSessionsCompanion.insert(
            id: 'seance',
            name: const Value('Push force'),
            status: 'COMPLETED',
            startedAt: DateTime.utc(2026, 9, 1, 17),
            endedAt: Value(DateTime.utc(2026, 9, 1, 18, 30)),
            durationSeconds: const Value(5400),
            syncStatus: const Value('synced'),
          ),
        );
    for (final (id, syncStatus) in [
      ('set-1', 'synced'),
      ('set-2', 'pending'),
    ]) {
      await db
          .into(db.localWorkoutSets)
          .insert(
            LocalWorkoutSetsCompanion.insert(
              id: id,
              sessionId: 'seance',
              exerciseName: 'Développé couché',
              position: id == 'set-1' ? 0 : 1,
              reps: const Value(8),
              weightKg: const Value(70),
              completedAt: DateTime.utc(2026, 9, 1, 17, 10),
              syncStatus: Value(syncStatus),
            ),
          );
    }
    await db
        .into(db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: 'op-close',
            entityType: 'session',
            entityId: 'seance',
            operationType: 'session.complete',
            payload: jsonEncode({
              'id': 'seance',
              'body': {'endedAt': '2026-09-01T18:30:00.000Z'},
            }),
            createdAt: clock,
            idempotencyKey: 'seance',
          ),
        );
    api.statusByEntityId['seance'] = 409;
  }

  Future<LocalWorkoutSession> localSession() => (db.select(
    db.localWorkoutSessions,
  )..where((row) => row.id.equals('seance'))).getSingle();

  Future<List<SyncOperation>> operations() =>
      db.select(db.syncOperations).get();

  group('résolveur', () {
    test('même issue côté serveur : la version serveur est adoptée', () async {
      await seedLocalCompletion();
      remote.session = _serverVersion(
        status: 'COMPLETED',
        sets: [
          RemoteWorkoutSet(
            id: 'set-1',
            exerciseName: 'Développé couché',
            position: 0,
            kind: 'NORMAL',
            reps: 8,
            weightKg: 72.5,
            completedAt: DateTime(2026, 9, 1, 17, 10),
          ),
        ],
      );

      await engine.syncNow();

      expect(await operations(), isEmpty);
      final session = await localSession();
      expect(session.syncStatus, 'synced');
      // Les dates du serveur font foi.
      expect(session.durationSeconds, 3600);
      // La série acquittée est remplacée par celle du serveur ; la série
      // encore en attente est CONSERVÉE : elle n'est pas à lui.
      final sets = await db.select(db.localWorkoutSets).get();
      final byId = {for (final set in sets) set.id: set};
      expect(byId.keys, containsAll(['set-1', 'set-2']));
      expect(byId['set-1']!.weightKg, 72.5);
      expect(byId['set-2']!.syncStatus, 'pending');
    });

    test('issue différente : conflit visible sur la séance', () async {
      await seedLocalCompletion();
      remote.session = _serverVersion(status: 'ABANDONED');

      await engine.syncNow();

      expect((await localSession()).syncStatus, 'conflict');
      expect((await operations()).single.status, 'conflict');
      // Rien n'a été réécrit : la copie locale reste la sienne.
      expect((await localSession()).status, 'COMPLETED');
    });

    test('hors ligne au moment de trancher : on retentera', () async {
      await seedLocalCompletion();
      remote.failure = const NetworkException('Serveur injoignable');

      await engine.syncNow();

      final operation = (await operations()).single;
      expect(operation.status, 'pending');
      expect(operation.attemptCount, 1);
      expect((await localSession()).syncStatus, 'synced');
    });

    test('séance inconnue du serveur : refus définitif', () async {
      await seedLocalCompletion();
      remote.failure = const ServerException('Introuvable', statusCode: 404);

      await engine.syncNow();

      expect((await operations()).single.status, 'failed');
      expect((await localSession()).syncStatus, 'failed');
    });

    test('le serveur ne la voit plus close : le rejeu passera', () async {
      await seedLocalCompletion();
      remote.session = _serverVersion(status: 'IN_PROGRESS');

      await engine.syncNow();

      expect((await operations()).single.status, 'pending');
    });
  });

  group('geste utilisateur', () {
    setUp(() async {
      await seedLocalCompletion();
      remote.session = _serverVersion(status: 'ABANDONED');
      await engine.syncNow();
      expect((await localSession()).syncStatus, 'conflict');
    });

    test(
      'prendre la version du serveur : elle remplace la copie locale',
      () async {
        await repository.resolveCloseConflict(
          'seance',
          WorkoutConflictResolution.takeServer,
        );

        final session = await localSession();
        expect(session.status, 'ABANDONED');
        expect(session.syncStatus, 'synced');
        expect(await operations(), isEmpty);
        // Le détail lu par l'écran reflète le choix.
        final detail = await repository.workoutDetail('seance');
        expect(detail!.session.status, WorkoutStatus.abandoned);
        expect(detail.session.syncState, LocalSyncState.synced);
        // La série jamais acquittée n'a pas été perdue.
        expect(detail.sets.map((set) => set.id), contains('set-2'));
      },
    );

    test('prendre la version du serveur hors ligne : rien ne bouge', () async {
      remote.failure = const NetworkException('Serveur injoignable');

      await expectLater(
        repository.resolveCloseConflict(
          'seance',
          WorkoutConflictResolution.takeServer,
        ),
        throwsA(isA<NetworkException>()),
      );

      expect((await localSession()).syncStatus, 'conflict');
      expect((await operations()).single.status, 'conflict');
    });

    test(
      'garder ma version : rejouée, puis échec visible si refusée',
      () async {
        await repository.resolveCloseConflict(
          'seance',
          WorkoutConflictResolution.keepLocal,
        );
        // `_poke` est lancé sans attente : on rejoint le drainage.
        await engine.syncNow();

        // Le serveur a répondu 409 de nouveau, avec la même version : la
        // question n'est pas reposée, l'échec est visible.
        final operation = (await operations()).single;
        expect(operation.status, 'failed');
        expect(operation.error, 'Le serveur a gardé sa version');
        expect(isArbitratedKeepLocal(operation), isTrue);
        final session = await localSession();
        expect(session.status, 'COMPLETED');
        expect(session.syncStatus, 'failed');
        expect(api.attemptsByEntityId['seance'], 2);
      },
    );

    test(
      'garder ma version : acceptée si le serveur a changé d’avis',
      () async {
        // Entre-temps, l'autre appareil a rejoué la même issue : le serveur
        // répond désormais 200 au rejeu.
        api.statusByEntityId.remove('seance');
        await repository.resolveCloseConflict(
          'seance',
          WorkoutConflictResolution.keepLocal,
        );
        await engine.syncNow();

        expect(await operations(), isEmpty);
        expect((await localSession()).syncStatus, 'synced');
        expect(api.log, ['session.complete:seance']);
      },
    );
  });
}
