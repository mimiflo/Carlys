import 'dart:convert';

import 'package:carlys_mobile/core/auth/token_storage.dart';
import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/core/synchronization/sync_owner.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_secure_storage.dart';
import '../../support/fake_sync_api.dart';

/// Résolveur de test : le compte connecté, ou personne.
class _FakeOwner implements SyncOwnerResolver {
  _FakeOwner(this.owner);

  String? owner;

  @override
  Future<String?> currentOwnerId() async => owner;
}

/// Un JWT non signé (la signature ne compte pas ici : seul le claim `sub`
/// est lu, pour un rangement local).
String _jwt(Map<String, Object?> claims) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode(claims)}.sig';
}

/// La file d'un compte ne part JAMAIS avec le jeton d'un autre.
void main() {
  group('propriétaire depuis le jeton', () {
    late FakeSecureStorage secure;
    late TokenSyncOwnerResolver resolver;

    setUp(() {
      secure = FakeSecureStorage();
      resolver = TokenSyncOwnerResolver(TokenStorage(secure));
    });

    test('lit le claim sub du jeton d’accès', () async {
      secure.values['carlys_access_token'] = _jwt({
        'sub': 'user-a',
        'sid': 'session-1',
      });
      expect(await resolver.currentOwnerId(), 'user-a');
    });

    test('personne sans jeton, ni avec un jeton illisible', () async {
      expect(await resolver.currentOwnerId(), isNull);
      secure.values['carlys_access_token'] = 'pas-un-jwt';
      expect(
        await TokenSyncOwnerResolver(TokenStorage(secure)).currentOwnerId(),
        isNull,
      );
    });

    test('jwtSubjectOf tolère les formes abîmées', () {
      expect(jwtSubjectOf('a.b'), isNull);
      expect(jwtSubjectOf('a.@@@.c'), isNull);
      expect(jwtSubjectOf(_jwt({'sid': 'seulement'})), isNull);
      expect(jwtSubjectOf(_jwt({'sub': ''})), isNull);
      expect(jwtSubjectOf(_jwt({'sub': 'user-b'})), 'user-b');
    });
  });

  group('drainage sous le bon compte', () {
    late AppDatabase db;
    late FakeSyncApi api;
    late _FakeOwner owner;
    late SyncEngine engine;
    final clock = DateTime.utc(2026, 9, 2, 8);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      api = FakeSyncApi();
      owner = _FakeOwner('user-b');
      engine = SyncEngine(
        database: db,
        api: api,
        owner: owner,
        now: () => clock,
      );
    });

    tearDown(() => db.close());

    Future<void> enqueue(String id, {String? writtenBy, int order = 0}) {
      return db
          .into(db.syncOperations)
          .insert(
            SyncOperationsCompanion.insert(
              id: id,
              entityType: 'session',
              entityId: id,
              operationType: 'session.create',
              payload: jsonEncode({'id': id}),
              createdAt: clock.add(Duration(seconds: order)),
              idempotencyKey: id,
              ownerUserId: Value(writtenBy),
            ),
          );
    }

    test(
      'une opération d’un autre compte est purgée, jamais envoyée',
      () async {
        // A s'est déconnecté sans que sa file parte ; B se connecte.
        await enqueue('seance-de-a', writtenBy: 'user-a');
        await enqueue('seance-de-b', writtenBy: 'user-b', order: 1);
        // Opération héritée d'avant la colonne : propriétaire inconnu,
        // elle part sous le compte connecté, comme avant.
        await enqueue('seance-heritee', order: 2);

        await engine.syncNow();

        expect(api.log, [
          'session.create:seance-de-b',
          'session.create:seance-heritee',
        ]);
        expect(api.attemptsByEntityId.containsKey('seance-de-a'), isFalse);
        expect(await db.select(db.syncOperations).get(), isEmpty);
      },
    );

    test('personne de connecté : la file attend, intacte', () async {
      owner.owner = null;
      await enqueue('seance-de-a', writtenBy: 'user-a');

      await engine.syncNow();

      expect(api.log, isEmpty);
      expect(await db.select(db.syncOperations).get(), hasLength(1));
    });

    test('sans résolveur, aucun contrôle (tests, démonstration)', () async {
      engine = SyncEngine(database: db, api: api, now: () => clock);
      await enqueue('seance-de-a', writtenBy: 'user-a');

      await engine.syncNow();

      expect(api.log, ['session.create:seance-de-a']);
    });

    test('une base fermée sous le drainage l’arrête sans erreur', () async {
      // À la frontière de compte, la purge ferme l'ancienne base pendant
      // qu'un envoi peut être en vol : le drainage, lancé sans attente, doit
      // se taire et le journaliser — jamais une erreur non interceptée.
      await enqueue('seance-de-b', writtenBy: 'user-b');
      api.networkDown = true;
      api.beforeCall = () async => db.close();

      await engine.syncNow();

      expect(api.attemptsByEntityId['seance-de-b'], 1);
    });
  });
}
