import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/environment/app_environment.dart';
import '../auth/jwt.dart';
import '../auth/token_deadline.dart';
import '../auth/token_refresher.dart';
import '../auth/token_storage.dart';

/// Ajoute le Bearer token et rejoue une fois la requête après un 401
/// si le rafraîchissement de session réussit.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._storage,
    required this._refresher,
    required this._dio,
  });

  static const _retriedKey = 'carlys_retried';

  /// Posé sur une requête dont le renouvellement d'avance vient d'ÉCHOUER :
  /// son 401 n'en relance pas un second.
  static const _preemptFailedKey = 'carlys_preempt_failed';

  final TokenStorage _storage;
  final TokenRefresher _refresher;
  final Dio _dio;
  final TokenDeadline _deadline = TokenDeadline();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    var accessToken = await _storage.readAccessToken();
    // Le jeton d'accès vit 15 min : au retour d'une pause plus longue, toute
    // la vague de requêtes partait avec un jeton expiré — 401, puis
    // rafraîchissement, puis rejeu. Il se renouvelle AVANT l'envoi, une
    // seule fois pour toute la vague (single-flight).
    if (accessToken != null && !_isAuthRoute(options)) {
      final pending = _refresher.inFlight;
      if (pending != null) {
        await pending;
        accessToken = await _storage.readAccessToken();
      } else if (_deadline.due(accessToken)) {
        if (await _renew()) {
          accessToken = await _storage.readAccessToken();
        } else {
          options.extra[_preemptFailedKey] = true;
        }
      }
    }
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  /// Renouvelle, et note l'issue pour l'échéance suivante. Un échec n'est
  /// jamais une exception ici : la requête part avec le jeton qu'elle a.
  Future<bool> _renew() async {
    try {
      if (await _refresher.refresh()) {
        final renewed = await _storage.readAccessToken();
        if (renewed != null) _deadline.renewed(renewed);
        return true;
      }
    } on Exception {
      // Journalisé par le rafraîchisseur ; la requête suit son cours.
    }
    _deadline.failed();
    return false;
  }

  /// Routes où un 401 dit « mot de passe incorrect », jamais « session
  /// expirée » : rafraîchir puis rejouer y comptait DEUX essais contre le
  /// verrouillage du compte pour une seule faute de frappe.
  static bool _checksPassword(RequestOptions options) =>
      options.path.contains('/auth/change-password') ||
      (options.method == 'DELETE' && options.path.endsWith('/users/me'));

  static bool _isAuthRoute(RequestOptions options) =>
      options.path.contains('/auth/refresh') ||
      options.path.contains('/auth/login') ||
      options.path.contains('/auth/register') ||
      // `/auth/social` OUVRE une session, elle n'en consomme pas : son 401
      // dit « ce jeton Google/Apple est refusé », jamais « ton accès a
      // expiré ». Rafraîchir puis rejouer y était inutile dans le meilleur
      // cas, et trompeur dans le pire — la seconde tentative renvoyait le
      // MÊME jeton du fournisseur et le même refus, en doublant l'attente.
      options.path.contains('/auth/social');

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final shouldRetry =
        err.response?.statusCode == 401 &&
        !_isAuthRoute(options) &&
        !_checksPassword(options) &&
        options.extra[_retriedKey] != true;
    if (!shouldRetry) {
      handler.next(err);
      return;
    }
    final sent = (options.headers['Authorization'] as String?)?.replaceFirst(
      'Bearer ',
      '',
    );
    final current = await _storage.readAccessToken();
    // Une requête d'un AUTRE compte (déconnexion puis connexion pendant son
    // envoi) n'est jamais rejouée sous le jeton du suivant : son corps
    // atterrirait chez lui.
    if (sent != null &&
        current != null &&
        jwtSubjectOf(sent) != jwtSubjectOf(current)) {
      handler.next(err);
      return;
    }
    // Partie avec un jeton que le rafraîchissement d'une requête voisine a
    // déjà remplacé : rejouer avec le nouveau suffit, sans en déclencher un
    // second (une rotation de plus, pour rien). Et si le renouvellement
    // d'avance de CETTE requête vient d'échouer, on n'en relance pas un
    // second : deux appels par requête quand le serveur peine.
    final replaced = current != null && sent != current;
    final retryRefresh = options.extra[_preemptFailedKey] != true;
    if (!replaced && !(retryRefresh && await _renew())) {
      handler.next(err);
      return;
    }

    try {
      options.extra[_retriedKey] = true;
      // Un corps multipart (la photo d'un repas) est un FLUX : lu une fois
      // par le premier envoi, il ne se relit pas, et Dio refuse de rejouer
      // un `FormData` déjà consommé. Il se CLONE avant d'être rejoué.
      final body = options.data;
      if (body is FormData) {
        options.data = body.clone();
      }
      final accessToken = await _storage.readAccessToken();
      options.headers['Authorization'] = 'Bearer $accessToken';
      final response = await _dio.fetch<Object?>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}

BaseOptions _baseOptions(AppEnvironment environment) => BaseOptions(
  baseUrl: environment.apiV1Url,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 20),
  contentType: 'application/json',
);

/// LE pool de connexions de l'application, partagé par les deux clients.
///
/// Dio ferme une connexion inactive après 3 s par défaut : presque chaque
/// changement d'écran rouvrait TCP et TLS — deux allers-retours de plus
/// avant la moindre réponse —, et le rafraîchissement de session, sur son
/// propre client, repartait toujours à froid. Gardées 30 s, sous les délais
/// des serveurs (Nginx 60 à 75 s, l'API 65 s) : c'est le client qui ferme
/// le premier, jamais une connexion morte réutilisée.
final httpAdapterProvider = Provider<HttpClientAdapter>((ref) {
  final adapter = IOHttpClientAdapter(
    createHttpClient: () =>
        HttpClient()..idleTimeout = const Duration(seconds: 30),
  );
  ref.onDispose(adapter.close);
  return adapter;
});

/// Dio nu réservé au rafraîchissement de session (aucun interceptor).
final bareDioProvider = Provider<Dio>((ref) {
  return Dio(_baseOptions(ref.watch(appEnvironmentProvider)))
    ..httpClientAdapter = ref.watch(httpAdapterProvider);
});

final tokenRefresherProvider = Provider<TokenRefresher>((ref) {
  return TokenRefresher(
    bareDio: ref.watch(bareDioProvider),
    storage: ref.watch(tokenStorageProvider),
  );
});

/// Client HTTP principal de l'application.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions(ref.watch(appEnvironmentProvider)))
    ..httpClientAdapter = ref.watch(httpAdapterProvider);
  dio.interceptors.add(
    AuthInterceptor(
      storage: ref.watch(tokenStorageProvider),
      refresher: ref.watch(tokenRefresherProvider),
      dio: dio,
    ),
  );
  if (kDebugMode) {
    // Jamais d'en-têtes dans les logs : le header Authorization y passerait.
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        responseHeader: false,
        requestBody: false,
        responseBody: false,
      ),
    );
  }
  return dio;
});
