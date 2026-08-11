import 'dart:async';
import 'dart:convert';

import 'package:carlys_mobile/core/database/app_database.dart';
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
    await db.into(db.syncOperations).insert(
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
      await (db.update(db.syncOperations)..where((op) => op.id.equals(id)))
          .write(
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
    test('une opération écrite pendant le drainage part sans attendre',
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
    });
  });
}
