import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/auth/token_storage.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/auth_session_device.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api.dart';
import '../dto/auth_dtos.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthApi api, required TokenStorage storage})
      : _api = api,
        _storage = storage;

  static const _logger = AppLogger('AuthRepository');

  final AuthApi _api;
  final TokenStorage _storage;

  static String get _devicePlatform =>
      Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'desktop');

  @override
  Future<bool> hasStoredSession() => _storage.hasSession;

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _guard(() async {
      final result = await _api.register(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
        devicePlatform: _devicePlatform,
      );
      await _saveTokens(result.tokens);
      return result.user.toEntity();
    });
  }

  @override
  Future<AuthUser> login({required String email, required String password}) {
    return _guard(() async {
      final result = await _api.login(
        email: email.trim(),
        password: password,
        devicePlatform: _devicePlatform,
      );
      await _saveTokens(result.tokens);
      return result.user.toEntity();
    });
  }

  @override
  Future<void> logout() async {
    try {
      await _api.logout();
    } on Exception catch (error) {
      // Hors ligne ou session déjà invalide : la déconnexion locale prime.
      _logger.warning('Révocation serveur impossible', error: error);
    } finally {
      await _storage.clear();
    }
  }

  @override
  Future<void> forgotPassword(String email) {
    return _guard(() => _api.forgotPassword(email.trim()));
  }

  @override
  Future<AuthUser> me() {
    return _guard(() async => (await _api.me()).toEntity());
  }

  @override
  Future<List<AuthSessionDevice>> sessions() {
    return _guard(() async {
      final sessions = await _api.sessions();
      return sessions.map((dto) => dto.toEntity()).toList();
    });
  }

  @override
  Future<void> revokeSession(String sessionId) {
    return _guard(() => _api.revokeSession(sessionId));
  }

  @override
  Future<void> revokeOtherSessions() {
    return _guard(() => _api.revokeOtherSessions());
  }

  Future<void> _saveTokens(AuthTokensDto tokens) => _storage.save(
        StoredTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        ),
      );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    api: AuthApi(ref.watch(dioProvider)),
    storage: ref.watch(tokenStorageProvider),
  );
});
