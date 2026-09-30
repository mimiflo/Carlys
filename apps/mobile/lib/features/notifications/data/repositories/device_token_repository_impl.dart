import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/repositories/device_token_repository.dart';

/// Jetons push servis par l'API (/api/v1/notifications/device-tokens).
class DeviceTokenRepositoryImpl implements DeviceTokenRepository {
  DeviceTokenRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> register({
    required String token,
    required DevicePlatform platform,
  }) {
    return guardDio(() async {
      await _dio.post<void>(
        '/notifications/device-tokens',
        data: {'token': token, 'platform': platform.wire},
      );
    });
  }

  @override
  Future<void> unregister(String token) {
    return guardDio(() async {
      await _dio.delete<void>(
        '/notifications/device-tokens',
        data: {'token': token},
      );
    });
  }

  @override
  Future<Map<NotificationCategory, bool>> preferences() {
    return guardDio(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/notifications/preferences',
      );
      final body = response.data?['data'] as Map<String, dynamic>? ?? const {};
      final entries = <NotificationCategory, bool>{};
      for (final raw in body['preferences'] as List<dynamic>? ?? const []) {
        if (raw is! Map<String, dynamic>) continue;
        final category = NotificationCategory.fromWire(
          raw['category'] as String,
        );
        if (category == null) continue;
        entries[category] = raw['enabled'] as bool? ?? true;
      }
      return entries;
    });
  }

  @override
  Future<void> setPreference(
    NotificationCategory category, {
    required bool enabled,
  }) {
    return guardDio(() async {
      await _dio.patch<void>(
        '/notifications/preferences',
        data: {'category': category.wire, 'enabled': enabled},
      );
    });
  }
}

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  return DeviceTokenRepositoryImpl(ref.watch(dioProvider));
});
