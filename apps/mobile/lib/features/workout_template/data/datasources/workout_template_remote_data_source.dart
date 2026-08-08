import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/workout_template.dart';
import '../dto/workout_template_dtos.dart';

/// Une page de `GET /api/v1/workout-templates` (pagination par curseur —
/// convention maison, jamais d'offset).
class WorkoutTemplatesPage {
  const WorkoutTemplatesPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<WorkoutTemplateInfo> items;
  final String? nextCursor;
  final bool hasMore;
}

/// Lectures serveur des modèles de séance.
///
/// **Les écritures ne passent pas ici** : elles vont dans la file de
/// synchronisation (`SyncApi.saveTemplate` / `deleteTemplate`), seul endroit
/// où vivent le rejeu, le backoff et l'idempotence. Cette source de données
/// ne sert qu'à *rapatrier* ce que le serveur détient — après une
/// réinstallation, par exemple.
abstract interface class WorkoutTemplateRemoteDataSource {
  Future<WorkoutTemplatesPage> list({String? cursor, int? limit});

  Future<WorkoutTemplateDetail> detail(String templateId);
}

class DioWorkoutTemplateRemoteDataSource
    implements WorkoutTemplateRemoteDataSource {
  const DioWorkoutTemplateRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<WorkoutTemplatesPage> list({String? cursor, int? limit}) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/workout-templates',
        queryParameters: {
          if (cursor != null) 'cursor': cursor,
          if (limit != null) 'limit': limit,
        },
      );

      final body = response.data ?? const <String, dynamic>{};
      final meta = body['meta'] as Map<String, dynamic>? ?? const {};
      return WorkoutTemplatesPage(
        items: (body['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(templateInfoFromJson)
            .toList(),
        nextCursor: meta['nextCursor'] as String?,
        hasMore: meta['hasMore'] as bool? ?? false,
      );
    });
  }

  @override
  Future<WorkoutTemplateDetail> detail(String templateId) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/workout-templates/$templateId',
      );
      return templateDetailFromJson(
        response.data?['data'] as Map<String, dynamic>? ?? const {},
      );
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final workoutTemplateRemoteDataSourceProvider =
    Provider<WorkoutTemplateRemoteDataSource>((ref) {
  return DioWorkoutTemplateRemoteDataSource(ref.watch(dioProvider));
});
