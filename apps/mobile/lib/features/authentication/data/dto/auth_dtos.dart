/// DTO du domaine authentification — parsing manuel des réponses JSON
/// (enveloppe { data, meta, requestId } déjà déballée par le datasource).
library;

import '../../domain/entities/auth_session_device.dart';
import '../../domain/entities/auth_user.dart';

class AuthUserDto {
  const AuthUserDto({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.locale,
    required this.timezone,
  });

  factory AuthUserDto.fromJson(Map<String, dynamic> json) => AuthUserDto(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        emailVerified: json['emailVerified'] as bool,
        locale: json['locale'] as String,
        timezone: json['timezone'] as String,
      );

  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;
  final String locale;
  final String timezone;

  AuthUser toEntity() => AuthUser(
        id: id,
        email: email,
        displayName: displayName,
        emailVerified: emailVerified,
        locale: locale,
        timezone: timezone,
      );
}

class AuthTokensDto {
  const AuthTokensDto({required this.accessToken, required this.refreshToken});

  factory AuthTokensDto.fromJson(Map<String, dynamic> json) => AuthTokensDto(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );

  final String accessToken;
  final String refreshToken;
}

class AuthResultDto {
  const AuthResultDto({required this.user, required this.tokens});

  factory AuthResultDto.fromJson(Map<String, dynamic> json) => AuthResultDto(
        user: AuthUserDto.fromJson(json['user'] as Map<String, dynamic>),
        tokens: AuthTokensDto.fromJson(json['tokens'] as Map<String, dynamic>),
      );

  final AuthUserDto user;
  final AuthTokensDto tokens;
}

class AuthSessionDto {
  const AuthSessionDto({
    required this.id,
    required this.current,
    required this.createdAt,
    required this.lastUsedAt,
    this.deviceName,
    this.devicePlatform,
  });

  factory AuthSessionDto.fromJson(Map<String, dynamic> json) => AuthSessionDto(
        id: json['id'] as String,
        current: json['current'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
        deviceName: json['deviceName'] as String?,
        devicePlatform: json['devicePlatform'] as String?,
      );

  final String id;
  final bool current;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final String? deviceName;
  final String? devicePlatform;

  AuthSessionDevice toEntity() => AuthSessionDevice(
        id: id,
        current: current,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt,
        deviceName: deviceName,
        devicePlatform: devicePlatform,
      );
}
