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
      await _storage.save(
        StoredTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        ),
      );
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
