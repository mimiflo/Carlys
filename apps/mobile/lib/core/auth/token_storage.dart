import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_logger.dart';

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
  static const _logger = AppLogger('TokenStorage');

  final FlutterSecureStorage _storage;
  String? _cachedAccessToken;
  bool _accessTokenLoaded = false;

  Future<String?> readAccessToken() async {
    if (_accessTokenLoaded) return _cachedAccessToken;
    try {
      _cachedAccessToken = await _storage.read(key: _accessTokenKey);
      _accessTokenLoaded = true;
      return _cachedAccessToken;
    } on PlatformException catch (error) {
      // Rien n'est mis en cache : le prochain appel relit le trousseau.
      _unreadable(error);
      return null;
    }
  }

  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } on PlatformException catch (error) {
      _unreadable(error);
      return null;
    }
  }

  /// Un trousseau ILLISIBLE jette à chaque lecture : clé Android perdue
  /// après une restauration de sauvegarde ou un transfert de téléphone
  /// (définitif), keystore occupé ou appareil verrouillé (passager). Sans
  /// garde, l'intercepteur d'authentification jetait avant tout envoi :
  /// TOUTES les requêtes échouaient, sur tout réseau, jusqu'à « Effacer les
  /// données ». La lecture rend désormais `null` : la requête part sans
  /// jeton et la personne peut se reconnecter.
  ///
  /// Rien n'est EFFACÉ : un échec passager détruirait une session encore
  /// valide, et dans le cas définitif la connexion suivante réécrit par-
  /// dessus l'entrée illisible (`save`). Pas `resetOnError` du greffon non
  /// plus : il répond à la lecture par une chaîne qui deviendrait le jeton.
  void _unreadable(PlatformException error) => _logger.warning(
    'Trousseau illisible : lecture rendue vide',
    error: error,
  );

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
