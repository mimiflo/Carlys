import 'dart:convert';

import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_conflict_resolver.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_sync_api.dart';

/// Résolveur de test : rend le verdict choisi et note les appels.
class _FakeResolver implements SyncConflictResolver {
  _FakeResolver(this.verdict);

  SyncConflictVerdict verdict;
  final List<String> calls = [];

  @override
  Future<SyncConflictVerdict> resolveClose(SyncOperation operation) async {
    calls.add(operation.operationType);
    return verdict;
  }
}

/// Un 409 à la clôture n'est plus un échec générique : le moteur demande un
/// verdict, et chaque verdict a une suite précise dans la file et sur la
/// séance.
void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late DateTime clock;
  late _FakeResolver resolver;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    clock = DateTime.utc(2026, 9, 1, 12);
    resolver = _FakeResolver(SyncConflictVerdict.conflict);
    engine = SyncEngine(
      database: db,
      api: api,
      conflictResolver: resolver,
      now: () => clock,
    );
  });

  tearDown(() => db.close());

  /// Une séance close localement, dont la clôture est en file — le serveur
  /// répondra 409.
  Future<void> seedClosedSession({
    String id = 'seance',
    bool arbitrated = false,
  }) async {
    await db
        .into(db.localWorkoutSessions)
        .insert(
          LocalWorkoutSessionsCompanion.insert(
            id: id,
            status: 'COMPLETED',
            startedAt: clock,
            syncStatus: const Value('synced'),
          ),
        );
    await db
        .into(db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: 'op-$id',
            entityType: 'session',
            entityId: id,
            operationType: 'session.complete',
            payload: jsonEncode({
              'id': id,
              'body': <String, dynamic>{},
              if (arbitrated) syncResolutionKey: syncKeepLocalResolution,
            }),
            createdAt: clock,
            idempotencyKey: id,
          ),
        );
    api.statusByEntityId[id] = 409;
  }

  Future<SyncOperation?> operationOf(String id) => (db.select(
    db.syncOperations,
  )..where((op) => op.id.equals('op-$id'))).getSingleOrNull();

  Future<String> sessionStateOf(String id) async => (await (db.select(
    db.localWorkoutSessions,
  )..where((row) => row.id.equals(id))).getSingle()).syncStatus;

  test(
    'conflit réel : l’opération attend, la séance passe en conflit',
    () async {
      await seedClosedSession();

      await engine.syncNow();

      expect(resolver.calls, ['session.complete']);
      final operation = (await operationOf('seance'))!;
      expect(operation.status, 'conflict');
      expect(operation.error, 'HTTP 409');
      expect(await sessionStateOf('seance'), 'conflict');

      // Un drainage suivant ne la renvoie pas : elle attend l'utilisateur.
      clock = clock.add(const Duration(minutes: 10));
      await engine.syncNow();
      expect(api.attemptsByEntityId['seance'], 1);
      expect(resolver.calls, hasLength(1));
    },
  );

  test(
    'même issue côté serveur : adoptée, l’opération est acquittée',
    () async {
      resolver.verdict = SyncConflictVerdict.adopted;
      await seedClosedSession();

      await engine.syncNow();

      expect(await operationOf('seance'), isNull);
      expect(await sessionStateOf('seance'), 'synced');
    },
  );

  test('version serveur inaccessible : on retentera, rien ne change', () async {
    resolver.verdict = SyncConflictVerdict.retryLater;
    await seedClosedSession();

    await engine.syncNow();

    final operation = (await operationOf('seance'))!;
    expect(operation.status, 'pending');
    expect(operation.attemptCount, 1);
    expect(await sessionStateOf('seance'), 'synced');
  });

  test('séance inconnue du serveur : refus définitif', () async {
    resolver.verdict = SyncConflictVerdict.rejected;
    await seedClosedSession();

    await engine.syncNow();

    final operation = (await operationOf('seance'))!;
    expect(operation.status, 'failed');
    expect(await sessionStateOf('seance'), 'failed');
  });

  test('sans résolveur, un 409 met directement la séance en conflit', () async {
    engine = SyncEngine(database: db, api: api, now: () => clock);
    await seedClosedSession();

    await engine.syncNow();

    expect((await operationOf('seance'))!.status, 'conflict');
    expect(await sessionStateOf('seance'), 'conflict');
  });

  test(
    'déjà arbitrée par l’utilisateur et encore refusée : échec, sans redemander',
    () async {
      await seedClosedSession(arbitrated: true);

      await engine.syncNow();

      final operation = (await operationOf('seance'))!;
      expect(operation.status, 'failed');
      expect(operation.error, 'Le serveur a gardé sa version');
      expect(await sessionStateOf('seance'), 'failed');
    },
  );

  test('un 409 hors clôture reste un refus définitif ordinaire', () async {
    await db
        .into(db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: 'op-set',
            entityType: 'set',
            entityId: 'set-1',
            operationType: 'set.upsert',
            payload: jsonEncode({
              'sessionId': 'seance',
              'body': {'id': 'set-1'},
            }),
            createdAt: clock,
            idempotencyKey: 'set-1',
          ),
        );
    api.statusByEntityId['set-1'] = 409;

    await engine.syncNow();

    expect(resolver.calls, isEmpty);
    final operation = await (db.select(
      db.syncOperations,
    )..where((op) => op.id.equals('op-set'))).getSingle();
    expect(operation.status, 'failed');
    expect(operation.error, 'HTTP 409');
  });

  test('une séance en conflit retient sa voie, pas les autres', () async {
    await seedClosedSession();
    // Rien ne suit normalement une clôture, mais si une opération de la
    // même séance existait, elle attendrait ; un modèle, lui, part.
    clock = clock.add(const Duration(seconds: 1));
    await db
        .into(db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: 'op-template',
            entityType: 'template',
            entityId: 'modele-1',
            operationType: 'template.delete',
            payload: '{}',
            createdAt: clock,
            idempotencyKey: 'modele-1',
          ),
        );

    await engine.syncNow();

    expect(api.log, ['template.delete:modele-1']);
    expect((await operationOf('seance'))!.status, 'conflict');
  });
}
