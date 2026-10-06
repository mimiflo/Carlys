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
  String? _renewedRefreshToken;
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
    // Celui que le serveur vient de rendre, même si le trousseau l'a refusé
    // (voir [save]) : l'ancien, relu, serait une réutilisation.
    final renewed = _renewedRefreshToken;
    if (renewed != null) return renewed;
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

  /// Le jeton de RENOUVELLEMENT d'abord : c'est lui que le serveur vient de
  /// faire tourner, et l'ancien, resté seul au trousseau, serait pris au
  /// prochain renouvellement pour une réutilisation — session fermée. Le
  /// jeton d'accès, lui, vit déjà en mémoire.
  ///
  /// Les DEUX restent en mémoire : si le trousseau refuse l'écriture
  /// (appareil verrouillé, keystore occupé), la session continue dans ce
  /// processus au lieu de renvoyer au serveur un jeton déjà consommé.
  Future<void> save(StoredTokens tokens) async {
    _cachedAccessToken = tokens.accessToken;
    _accessTokenLoaded = true;
    _renewedRefreshToken = tokens.refreshToken;
    await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
    await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
  }

  Future<void> clear() async {
    _cachedAccessToken = null;
    _renewedRefreshToken = null;
    _accessTokenLoaded = true;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStorage());
});
