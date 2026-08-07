import 'package:carlys_mobile/core/auth/token_storage.dart';
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
      containsAll(<String>[
        'carlys_access_token',
        'carlys_refresh_token',
      ]),
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
}
