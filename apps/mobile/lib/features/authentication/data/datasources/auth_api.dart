import 'package:dio/dio.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/errors/app_exception.dart';
import '../dto/auth_dtos.dart';

/// Datasource HTTP du domaine authentification.
/// Déballe l'enveloppe { data, meta, requestId } et retourne des DTO.
///
/// Les corps se demandent NON typés (`Object?`) et se vérifient ici : typés
/// `Map<String, dynamic>`, un corps d'une autre forme (page HTML, liste)
/// échouait DANS Dio, enveloppé comme une coupure réseau, et la personne
/// lisait « serveur injoignable » à propos d'un hôte qui avait répondu.
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
    final response = await _dio.post<Object?>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'displayName': displayName,
        if (deviceName != null) 'deviceName': deviceName,
        if (devicePlatform != null) 'devicePlatform': devicePlatform,
      },
    );
    return _read(response, AuthResultDto.fromJson);
  }

  Future<AuthResultDto> login({
    required String email,
    required String password,
    String? deviceName,
    String? devicePlatform,
  }) async {
    final response = await _dio.post<Object?>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        if (deviceName != null) 'deviceName': deviceName,
        if (devicePlatform != null) 'devicePlatform': devicePlatform,
      },
    );
    return _read(response, AuthResultDto.fromJson);
  }

  /// Échange un jeton d'identité Apple/Google contre une session Carlys.
  ///
  /// Le serveur VÉRIFIE le jeton (signature du fournisseur, émetteur,
  /// audience) avant d'ouvrir quoi que ce soit : ce que l'appareil envoie
  /// ici est une preuve à contrôler, pas une décision.
  Future<AuthResultDto> socialLogin({
    required String provider,
    required String idToken,
    String? displayName,
    String? deviceName,
    String? devicePlatform,
  }) async {
    final response = await _dio.post<Object?>(
      '/auth/social',
      data: {
        'provider': provider,
        'idToken': idToken,
        if (displayName != null) 'displayName': displayName,
        if (deviceName != null) 'deviceName': deviceName,
        if (devicePlatform != null) 'devicePlatform': devicePlatform,
      },
    );
    return _read(response, AuthResultDto.fromJson);
  }

  Future<void> logout() => _dio.post<void>('/auth/logout');

  Future<void> forgotPassword(String email) =>
      _dio.post<void>('/auth/forgot-password', data: {'email': email});

  Future<AuthUserDto> me() async {
    final response = await _dio.get<Object?>('/users/me');
    return _read(response, AuthUserDto.fromJson);
  }

  /// PATCH /users/me — n'envoie QUE le fuseau : le corps décrit ce qui
  /// change, et le serveur laisse le reste du profil intact.
  Future<AuthUserDto> updateTimezone(String timezone) async {
    final response = await _dio.patch<Object?>(
      '/users/me',
      data: {'timezone': timezone},
    );
    return _read(response, AuthUserDto.fromJson);
  }

  Future<List<AuthSessionDto>> sessions() async {
    final response = await _dio.get<Object?>('/auth/sessions');
    return _readEnvelope(response, (data) {
      if (data is! List) {
        throw const FormatException('Liste de sessions attendue');
      }
      return data
          .whereType<Map<String, dynamic>>()
          .map(AuthSessionDto.fromJson)
          .toList();
    });
  }

  Future<void> revokeSession(String sessionId) =>
      _dio.delete<void>('/auth/sessions/$sessionId');

  Future<void> revokeOtherSessions() => _dio.delete<void>('/auth/sessions');

  /// POST /auth/change-password — 204, et le serveur révoque les autres
  /// sessions dans la foulée.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _dio.post<void>(
    '/auth/change-password',
    data: {'currentPassword': currentPassword, 'newPassword': newPassword},
  );

  /// DELETE /users/me — 204. Le mot de passe voyage dans le CORPS : c'est ce
  /// que le contrôleur `DeleteAccountDto` exige.
  Future<void> deleteAccount(String password) =>
      _dio.delete<void>('/users/me', data: {'password': password});

  /// POST /auth/resend-verification — 204, même réponse si l'adresse est
  /// déjà vérifiée.
  Future<void> resendEmailVerification() =>
      _dio.post<void>('/auth/resend-verification');

  /// Lit l'objet `data` d'une réponse 2xx, puis le DTO qu'il porte.
  T _read<T>(
    Response<Object?> response,
    T Function(Map<String, dynamic> json) parse,
  ) => _readEnvelope(response, (data) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Enveloppe de réponse inattendue');
    }
    return parse(data);
  });

  /// Déballe `{ data, meta, requestId }` et confie `data` à [parse].
  ///
  /// Tout ce qui ne se lit pas devient [MalformedResponseException] : un
  /// corps qui n'est pas un objet JSON, une enveloppe absente
  /// (`FormatException`), un champ manquant ou d'un autre type (`TypeError`
  /// des DTO, lus à la main par `as`). Les trois disent la même chose : ce
  /// qui a répondu et l'application ne parlent pas le même contrat. La
  /// conversion se fait ICI, où la réponse est encore là : son en-tête dit
  /// si c'est bien l'API Carlys qui a répondu.
  T _readEnvelope<T>(
    Response<Object?> response,
    T Function(Object? data) parse,
  ) {
    try {
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Corps de réponse qui n’est pas un objet');
      }
      return parse(body['data']);
    } on FormatException catch (error, trace) {
      throw _malformed(response, error, trace);
    } on TypeError catch (error, trace) {
      throw _malformed(response, error, trace);
    }
  }

  MalformedResponseException _malformed(
    Response<Object?> response,
    Object error,
    StackTrace trace,
  ) => MalformedResponseException(
    'Réponse de ${response.requestOptions.path} illisible',
    requestId: requestIdOf(response.headers),
    cause: error,
    stackTrace: trace,
  );
}
