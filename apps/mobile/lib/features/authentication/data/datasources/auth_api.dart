import 'package:dio/dio.dart';

import '../dto/auth_dtos.dart';

/// Datasource HTTP du domaine authentification.
/// Déballe l'enveloppe { data, meta, requestId } et retourne des DTO.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthResultDto> register({
    required String email,
    required String password,
    required String displayName,
    String? deviceName,
    String? devicePlatform,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'displayName': displayName,
        if (deviceName != null) 'deviceName': deviceName,
        if (devicePlatform != null) 'devicePlatform': devicePlatform,
      },
    );
    return AuthResultDto.fromJson(_data(response));
  }

  Future<AuthResultDto> login({
    required String email,
    required String password,
    String? deviceName,
    String? devicePlatform,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        if (deviceName != null) 'deviceName': deviceName,
        if (devicePlatform != null) 'devicePlatform': devicePlatform,
      },
    );
    return AuthResultDto.fromJson(_data(response));
  }

  Future<void> logout() => _dio.post<void>('/auth/logout');

  Future<void> forgotPassword(String email) =>
      _dio.post<void>('/auth/forgot-password', data: {'email': email});

  Future<AuthUserDto> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/me');
    return AuthUserDto.fromJson(_data(response));
  }

  Future<List<AuthSessionDto>> sessions() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/sessions');
    final list = response.data?['data'];
    if (list is! List) {
      throw const FormatException('Liste de sessions attendue');
    }
    return list
        .whereType<Map<String, dynamic>>()
        .map(AuthSessionDto.fromJson)
        .toList();
  }

  Future<void> revokeSession(String sessionId) =>
      _dio.delete<void>('/auth/sessions/$sessionId');

  Future<void> revokeOtherSessions() => _dio.delete<void>('/auth/sessions');

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Enveloppe de réponse inattendue');
    }
    return data;
  }
}
