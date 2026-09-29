import 'package:carlys_mobile/core/auth/token_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_secure_storage.dart';

void main() {
  test('sauvegarde, lit et efface la paire de jetons', () async {
    final secureStorage = FakeSecureStorage();
    final storage = TokenStorage(secureStorage);

    expect(await storage.readAccessToken(), isNull);
    expect(await storage.hasSession, isFalse);

    await storage.save(
      const StoredTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );

    expect(await storage.readAccessToken(), 'access-1');
    expect(await storage.readRefreshToken(), 'refresh-1');
    expect(await storage.hasSession, isTrue);
    // Les jetons ne partent jamais dans les préférences classiques :
    // ils sont bien dans le stockage sécurisé injecté.
    expect(
      secureStorage.values.keys,
      containsAll(<String>['carlys_access_token', 'carlys_refresh_token']),
    );

    await storage.clear();
    expect(await storage.readAccessToken(), isNull);
    expect(await storage.hasSession, isFalse);
    expect(secureStorage.values, isEmpty);
  });

  test('le cache mémoire suit les écritures successives', () async {
    final storage = TokenStorage(FakeSecureStorage());

    await storage.save(
      const StoredTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );
    await storage.save(
      const StoredTokens(accessToken: 'access-2', refreshToken: 'refresh-2'),
    );

    expect(await storage.readAccessToken(), 'access-2');
    expect(await storage.readRefreshToken(), 'refresh-2');
  });

  group('trousseau illisible (clé perdue, keystore occupé)', () {
    final illisible = PlatformException(code: 'Exception encountered');

    test('aucune session, mais rien n’est effacé', () async {
      final secureStorage = FakeSecureStorage()
        ..values['carlys_access_token'] = 'chiffre-avec-une-cle-perdue'
        ..values['carlys_refresh_token'] = 'chiffre-avec-une-cle-perdue'
        ..failReads = illisible;
      final storage = TokenStorage(secureStorage);

      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
      expect(await storage.hasSession, isFalse);
      expect(secureStorage.values, hasLength(2));
    });

    test('un échec passager ne perd pas la session : on relit', () async {
      final secureStorage = FakeSecureStorage()
        ..values['carlys_access_token'] = 'access-1'
        ..values['carlys_refresh_token'] = 'refresh-1'
        ..failReads = illisible;
      final storage = TokenStorage(secureStorage);
      expect(await storage.readAccessToken(), isNull);

      secureStorage.failReads = null;

      expect(await storage.readAccessToken(), 'access-1');
      expect(await storage.hasSession, isTrue);
    });

    test('la connexion suivante réécrit une session lisible', () async {
      final secureStorage = FakeSecureStorage()
        ..values['carlys_refresh_token'] = 'chiffre-avec-une-cle-perdue'
        ..failReads = illisible;
      final storage = TokenStorage(secureStorage);
      expect(await storage.hasSession, isFalse);

      await storage.save(
        const StoredTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
      secureStorage.failReads = null;

      expect(await storage.readAccessToken(), 'access-1');
      expect(await storage.readRefreshToken(), 'refresh-1');
    });
  });
}
