import 'dart:async';
import 'dart:convert';

import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_dispatcher.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../../support/fake_sync_api.dart';

/// Robustesse du moteur de synchronisation, au-delà du chemin heureux.
///
/// Chacun de ces cas a été un vrai défaut : ils sont pinnés pour ne pas
/// revenir.
void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late SyncEngine engine;
  late DateTime clock;
  const uuid = Uuid();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    clock = DateTime.utc(2026, 8, 10, 12);
    engine = SyncEngine(database: db, api: api, now: () => clock);
  });

  tearDown(() => db.close());

  Future<String> enqueue({
    String operationType = 'session.create',
    String entityType = 'session',
    Map<String, dynamic>? payload,
    int attemptCount = 0,
    DateTime? lastAttemptAt,
  }) async {
    final id = uuid.v4();
    await db
        .into(db.syncOperations)
        .insert(
          SyncOperationsCompanion.insert(
            id: id,
            entityType: entityType,
            entityId: id,
            operationType: operationType,
            payload: jsonEncode(payload ?? {'id': id}),
            createdAt: clock,
            idempotencyKey: id,
          ),
        );
    if (attemptCount > 0) {
      await (db.update(
        db.syncOperations,
      )..where((op) => op.id.equals(id))).write(
        SyncOperationsCompanion(
          attemptCount: Value(attemptCount),
          lastAttemptAt: Value(lastAttemptAt ?? clock),
        ),
      );
    }
    return id;
  }

  Future<List<SyncOperation>> allOperations() =>
      db.select(db.syncOperations).get();

  group('backoff', () {
    test('plafonne à 5 minutes dès la septième tentative', () {
      expect(SyncEngine.backoff(1), const Duration(seconds: 5));
      expect(SyncEngine.backoff(2), const Duration(seconds: 10));
      expect(SyncEngine.backoff(7), const Duration(minutes: 5));
    });

    test('survit à des milliers de tentatives', () {
      // pow(2, n) déborde en infini vers n = 1024 — trois jours de replis à
      // 5 minutes. `infinity.toInt()` jette : sans borne sur l'exposant, la
      // synchronisation mourait définitivement au millième échec.
      expect(SyncEngine.backoff(1025), const Duration(minutes: 5));
      expect(SyncEngine.backoff(1000000), const Duration(minutes: 5));
    });

    test('une opération très ancienne reste rejouable', () async {
      api.networkDown = true;
      await enqueue(
        attemptCount: 2000,
        lastAttemptAt: clock.subtract(const Duration(days: 4)),
      );
      // Ne doit ni jeter ni ignorer l'opération : le backoff est échu.
      await engine.syncNow();
      final operation = (await allOperations()).single;
      expect(operation.attemptCount, 2001);
    });
  });

  group('plafond de tentatives', () {
    /// Fait échouer [id] avec un 503 jusqu'à ce que le plafond soit atteint,
    /// en laissant passer le backoff (plafonné à 5 min) entre deux essais.
    Future<void> exhaust(String id) async {
      api.statusByEntityId[id] = 503;
      for (var i = 0; i < SyncEngine.serverAttemptsMax; i++) {
        clock = clock.add(const Duration(minutes: 6));
        await engine.syncNow();
      }
    }

    test('une opération empoisonnée est mise de côté ; sa voie attend, '
        'les autres partent', () async {
      // Une séance dont la création répond 503 pour toujours.
      final poisoned = await enqueue();
      await db
          .into(db.localWorkoutSessions)
          .insert(
            LocalWorkoutSessionsCompanion.insert(
              id: poisoned,
              status: 'IN_PROGRESS',
              startedAt: clock,
            ),
          );
      clock = clock.add(const Duration(seconds: 1));
      // Une série de CETTE séance : elle ne doit jamais partir avant la
      // création, sinon le serveur la refuserait pour de bon (404).
      final dependent = await enqueue(
        operationType: 'set.upsert',
        entityType: 'set',
        payload: {
          'sessionId': poisoned,
          'body': {'id': 'set-1'},
        },
      );
      clock = clock.add(const Duration(seconds: 1));
      // Un modèle : rien à voir avec cette séance.
      final independent = await enqueue(
        operationType: 'template.save',
        entityType: 'template',
        payload: {'body': <String, dynamic>{}},
      );

      await exhaust(poisoned);

      final byId = {for (final op in await allOperations()) op.id: op};
      final stalled = byId[poisoned]!;
      expect(stalled.status, 'exhausted');
      expect(stalled.serverErrorCount, SyncEngine.serverAttemptsMax);
      expect(stalled.error, 'HTTP 503');
      expect(api.attemptsByEntityId[poisoned], SyncEngine.serverAttemptsMax);
      // La série attend sur sa voie, intacte : jamais envoyée.
      expect(byId[dependent]!.status, 'pending');
      expect(api.attemptsByEntityId.containsKey('set-1'), isFalse);
      // Le modèle est passé (donc purgé) : la file n'est plus bloquée.
      expect(byId.containsKey(independent), isFalse);
      expect(api.log, ['template.save:$independent']);
      // L'écran voit la séance en échec, pas en attente indéfinie.
      final session = await db.select(db.localWorkoutSessions).getSingle();
      expect(session.syncStatus, 'failed');
    });

    test(
      'mise de côté, elle repart à l’ouverture suivante, en ordre',
      () async {
        final poisoned = await enqueue();
        await db
            .into(db.localWorkoutSessions)
            .insert(
              LocalWorkoutSessionsCompanion.insert(
                id: poisoned,
                status: 'IN_PROGRESS',
                startedAt: clock,
              ),
            );
        clock = clock.add(const Duration(seconds: 1));
        await enqueue(
          operationType: 'set.upsert',
          entityType: 'set',
          payload: {
            'sessionId': poisoned,
            'body': {'id': 'set-1'},
          },
        );
        await exhaust(poisoned);
        expect(api.log, isEmpty);

        // Le serveur va mieux ; l'application est rouverte.
        api.statusByEntityId.remove(poisoned);
        await engine.retryExhausted();
        final session = await db.select(db.localWorkoutSessions).getSingle();
        expect(session.syncStatus, 'pending');
        await engine.syncNow();

        expect(api.log, ['session.create:$poisoned', 'set.upsert:set-1']);
        expect(await allOperations(), isEmpty);
      },
    );

    test('une coupure réseau ne compte jamais comme erreur serveur', () async {
      // Hors ligne pendant une heure : la file ne doit pas se vider dans
      // « mis de côté » opération par opération — c'est le réseau qui
      // manque, pas l'opération qui est mauvaise.
      api.networkDown = true;
      final id = await enqueue();
      for (var i = 0; i < 2 * SyncEngine.serverAttemptsMax; i++) {
        clock = clock.add(const Duration(minutes: 6));
        await engine.syncNow();
      }
      final operation = (await allOperations()).single;
      expect(operation.status, 'pending');
      expect(operation.serverErrorCount, 0);
      expect(operation.attemptCount, 2 * SyncEngine.serverAttemptsMax);
      expect(api.attemptsByEntityId[id], 2 * SyncEngine.serverAttemptsMax);
    });

    test(
      'un 429 est transitoire : ni échec définitif, ni erreur serveur',
      () async {
        // La documentation le promettait ; le moteur le rangeait avec les 4xx
        // définitifs, et une rafale de saisies aurait marqué en échec des
        // séries parfaitement valides.
        final id = await enqueue();
        api.statusByEntityId[id] = 429;
        await engine.syncNow();
        api.statusByEntityId.remove(id);

        final operation = (await allOperations()).single;
        expect(operation.status, 'pending');
        expect(operation.serverErrorCount, 0);
        expect(operation.attemptCount, 1);
      },
    );

    test('un 5xx isolé ne fait qu’attendre le backoff', () async {
      final id = await enqueue();
      api.statusByEntityId[id] = 502;
      await engine.syncNow();
      api.statusByEntityId.remove(id);

      final operation = (await allOperations()).single;
      expect(operation.status, 'pending');
      expect(operation.serverErrorCount, 1);
      // Trop tôt : le backoff de 5 s n'est pas écoulé.
      await engine.syncNow();
      expect(api.attemptsByEntityId[id], 1);
      clock = clock.add(const Duration(seconds: 6));
      await engine.syncNow();
      expect(api.log, ['session.create:$id']);
    });
  });

  group('voies', () {
    SyncOperation operationOf({
      required String entityType,
      required String entityId,
      required String payload,
    }) => SyncOperation(
      id: 'op',
      entityType: entityType,
      entityId: entityId,
      operationType: 'x',
      payload: payload,
      createdAt: clock,
      attemptCount: 0,
      serverErrorCount: 0,
      status: 'pending',
      idempotencyKey: entityId,
    );

    test('les opérations d’une séance partagent une voie', () {
      expect(
        syncLaneOf(
          operationOf(entityType: 'session', entityId: 's-1', payload: '{}'),
        ),
        'session:s-1',
      );
      expect(
        syncLaneOf(
          operationOf(entityType: 'plan', entityId: 's-1', payload: '{}'),
        ),
        'session:s-1',
      );
      expect(
        syncLaneOf(
          operationOf(
            entityType: 'set',
            entityId: 'set-1',
            payload: '{"sessionId":"s-1","body":{}}',
          ),
        ),
        'session:s-1',
      );
    });

    test('un modèle et une série sans séance connue font voie à part', () {
      expect(
        syncLaneOf(
          operationOf(entityType: 'template', entityId: 't-1', payload: '{}'),
        ),
        'template:t-1',
      );
      // Opération écrite avant que `set.delete` ne porte `sessionId`.
      expect(
        syncLaneOf(
          operationOf(
            entityType: 'set',
            entityId: 'set-1',
            payload: '{"id":"set-1"}',
          ),
        ),
        'set:set-1',
      );
      // Charge illisible : ne fait surtout pas tomber le drainage.
      expect(
        syncLaneOf(
          operationOf(entityType: 'set', entityId: 'set-1', payload: '{'),
        ),
        'set:set-1',
      );
    });
  });

  group('clé d’idempotence', () {
    test('chaque envoi transmet la clé stockée dans la file', () async {
      // La colonne existait, mais rien ne partait : la clé est justement ce
      // qui permet au serveur de retrouver les rejeux d'une même opération.
      final first = await enqueue();
      final second = await enqueue(
        operationType: 'set.delete',
        entityType: 'set',
      );

      await engine.syncNow();

      expect(api.idempotencyKeys, [first, second]);
    });
  });

  group('opération inconnue ou malformée', () {
    test('un type inconnu est marqué en échec, la file continue', () async {
      // Le cas n'est pas théorique : une version plus récente de
      // l'application écrit un type d'opération, puis l'utilisateur revient
      // en arrière. `StateError` est une `Error`, qu'un `on Exception`
      // laissait passer — la tête de file restait bloquée pour toujours.
      await enqueue(operationType: 'session.futur');
      final valid = await enqueue();

      await engine.syncNow();

      final byStatus = {
        for (final op in await allOperations()) op.operationType: op.status,
      };
      expect(byStatus['session.futur'], 'failed');
      // L'opération valide derrière est bien passée (donc purgée).
      expect(byStatus.containsKey('session.create'), isFalse);
      expect(api.log, ['session.create:$valid']);
    });

    test('une charge utile malformée n’est pas bloquante', () async {
      // `payload['body'] as Map` jette une TypeError si `body` manque.
      await enqueue(
        operationType: 'session.complete',
        payload: {'pasDeBody': true},
      );
      final valid = await enqueue();

      await engine.syncNow();

      expect(api.log, ['session.create:$valid']);
      final failed = (await allOperations()).single;
      expect(failed.status, 'failed');
    });
  });

  group('réveil pendant un drainage', () {
    test(
      'une opération écrite pendant le drainage part sans attendre',
      () async {
        // Sans la note de re-drainage, l'opération écrite pendant l'envoi de la
        // première attendait le réveil périodique — trois minutes plus tard.
        final gate = Completer<void>();
        api.beforeCall = () => gate.future;
        await enqueue();

        final firstDrain = engine.syncNow();
        // Pendant que la première opération est en vol, une seconde s'écrit.
        final second = await enqueue();
        final poke = engine.syncNow();
        api.beforeCall = null;
        gate.complete();
        await firstDrain;
        await poke;

        expect(api.log, hasLength(2));
        expect(api.log.last, 'session.create:$second');
        expect(await allOperations(), isEmpty);
      },
    );
  });
}
