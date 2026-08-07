import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../dto/progress_dtos.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl(this._dio, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final Dio _dio;
  final Uuid _uuid;

  @override
  Future<ProgressOverviewEntity> overview(ProgressPeriod period) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/progress/overview',
        queryParameters: {'period': period.apiValue},
      );
      return progressOverviewFromJson(
        response.data?['data'] as Map<String, dynamic>? ?? const {},
      );
    });
  }

  @override
  Future<List<PersonalRecordEntry>> records() {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/progress/records');
      return (response.data?['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(personalRecordFromJson)
          .toList();
    });
  }

  @override
  Future<List<BodyMetricEntry>> bodyMetrics({
    BodyMetricKind kind = BodyMetricKind.weightKg,
    int limit = 90,
  }) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/body-metrics',
        queryParameters: {'metricType': kind.apiValue, 'limit': limit},
      );
      return (response.data?['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(bodyMetricFromJson)
          .toList();
    });
  }

  @override
  Future<BodyMetricEntry> addBodyMetric({
    required BodyMetricKind kind,
    required double value,
    required DateTime measuredAt,
  }) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/body-metrics',
        data: {
          // Id généré ici : renvoyer la même requête ne crée aucun doublon.
          'id': _uuid.v4(),
          'metricType': kind.apiValue,
          'value': value,
          'measuredAt': measuredAt.toUtc().toIso8601String(),
        },
      );
      return bodyMetricFromJson(
        response.data?['data'] as Map<String, dynamic>? ?? const {},
      );
    });
  }

  @override
  Future<void> deleteBodyMetric(String id) {
    return _guard(() => _dio.delete<void>('/body-metrics/$id'));
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepositoryImpl(ref.watch(dioProvider));
});
