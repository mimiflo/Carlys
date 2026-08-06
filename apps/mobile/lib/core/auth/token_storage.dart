import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Paire de jetons de session.
class StoredTokens {
  const StoredTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Stockage des jetons dans le trousseau sécurisé de la plateforme
/// (Keychain iOS / Keystore Android) — JAMAIS dans SharedPreferences.
///
/// L'access token est mis en cache mémoire pour éviter une lecture
/// asynchrone du trousseau à chaque requête.
class TokenStorage {
  TokenStorage(this._storage);

  static const _accessTokenKey = 'carlys_access_token';
  static const _refreshTokenKey = 'carlys_refresh_token';

  final FlutterSecureStorage _storage;
  String? _cachedAccessToken;
  bool _accessTokenLoaded = false;

  Future<String?> readAccessToken() async {
    if (!_accessTokenLoaded) {
      _cachedAccessToken = await _storage.read(key: _accessTokenKey);
      _accessTokenLoaded = true;
    }
    return _cachedAccessToken;
  }

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<bool> get hasSession async => await readRefreshToken() != null;

  Future<void> save(StoredTokens tokens) async {
    _cachedAccessToken = tokens.accessToken;
    _accessTokenLoaded = true;
    await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
  }

  Future<void> clear() async {
    _cachedAccessToken = null;
    _accessTokenLoaded = true;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStorage());
});
