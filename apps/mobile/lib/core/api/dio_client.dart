import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/environment/app_environment.dart';
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

  final TokenStorage _storage;
  final TokenRefresher _refresher;
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _storage.readAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isAuthRoute =
        options.path.contains('/auth/refresh') ||
        options.path.contains('/auth/login') ||
        options.path.contains('/auth/register') ||
        // `/auth/social` OUVRE une session, elle n'en consomme pas : son 401
        // dit « ce jeton Google/Apple est refusé », jamais « ton accès a
        // expiré ». Rafraîchir puis rejouer y était inutile dans le meilleur
        // cas, et trompeur dans le pire — la seconde tentative renvoyait le
        // MÊME jeton du fournisseur et le même refus, en doublant l'attente.
        options.path.contains('/auth/social');
    final shouldRetry =
        err.response?.statusCode == 401 &&
        !isAuthRoute &&
        options.extra[_retriedKey] != true;

    if (!shouldRetry || !await _refresher.refresh()) {
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

/// Dio nu réservé au rafraîchissement de session (aucun interceptor).
final bareDioProvider = Provider<Dio>((ref) {
  return Dio(_baseOptions(ref.watch(appEnvironmentProvider)));
});

final tokenRefresherProvider = Provider<TokenRefresher>((ref) {
  return TokenRefresher(
    bareDio: ref.watch(bareDioProvider),
    storage: ref.watch(tokenStorageProvider),
  );
});

/// Client HTTP principal de l'application.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions(ref.watch(appEnvironmentProvider)));
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
