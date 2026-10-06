import 'package:dio/dio.dart';

import '../logging/app_logger.dart';
import 'token_storage.dart';

/// Renouvelle la paire de jetons via POST /auth/refresh.
///
/// Single-flight : plusieurs requêtes 401 simultanées ne déclenchent qu'un
/// seul appel de rafraîchissement — les autres attendent le même futur.
/// Utilise un Dio nu (sans interceptors) pour éviter toute récursion.
class TokenRefresher {
  TokenRefresher({required Dio bareDio, required this._storage})
    : _dio = bareDio;

  static const _logger = AppLogger('TokenRefresher');

  final Dio _dio;
  final TokenStorage _storage;
  Future<bool>? _inFlight;

  /// Invoqué quand la session est définitivement invalide (reconnexion requise).
  void Function()? onSessionExpired;

  /// Un rafraîchissement en cours, ou `null` : une requête qui part pendant
  /// ce temps l'attend au lieu d'envoyer le jeton qu'il remplace.
  Future<bool>? get inFlight => _inFlight;

  /// Retourne true si de nouveaux jetons ont été obtenus.
  Future<bool> refresh() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<bool> _refresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) {
      return false;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        _logger.error('Réponse de rafraîchissement inattendue');
        return false;
      }
      try {
        await _storage.save(
          StoredTokens(
            accessToken: data['accessToken'] as String,
            refreshToken: data['refreshToken'] as String,
          ),
        );
      } on Exception catch (error) {
        // Le trousseau a refusé (appareil verrouillé, keystore occupé) : le
        // jeton d'accès neuf est déjà en mémoire et sert la séance ; seule
        // la persistance a manqué, et elle ne doit pas faire tomber toutes
        // les requêtes qui attendaient ce renouvellement.
        _logger.error('Jetons renouvelés non persistés', error: error);
      }
      return true;
    } on DioException catch (exception) {
      final status = exception.response?.statusCode;
      if (status == 401) {
        // Session révoquée, expirée ou réutilisation détectée côté serveur.
        _logger.info('Session invalide : reconnexion nécessaire');
        await _storage.clear();
        onSessionExpired?.call();
      } else {
        _logger.warning('Rafraîchissement impossible', error: exception);
      }
      return false;
    }
  }
}
