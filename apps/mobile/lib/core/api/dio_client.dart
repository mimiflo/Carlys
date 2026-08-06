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
    required TokenStorage storage,
    required TokenRefresher refresher,
    required Dio dio,
  })  : _storage = storage,
        _refresher = refresher,
        _dio = dio;

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
    final isAuthRoute = options.path.contains('/auth/refresh') ||
        options.path.contains('/auth/login') ||
        options.path.contains('/auth/register');
    final shouldRetry = err.response?.statusCode == 401 &&
        !isAuthRoute &&
        options.extra[_retriedKey] != true;

    if (!shouldRetry || !await _refresher.refresh()) {
      handler.next(err);
      return;
    }

    try {
      options.extra[_retriedKey] = true;
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
