import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/repositories/exercises_repository.dart';
import '../dto/exercise_dtos.dart';

class ExercisesRepositoryImpl implements ExercisesRepository {
  ExercisesRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ExercisesPage> list({
    ExercisesFilters filters = const ExercisesFilters(),
    String? cursor,
  }) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/exercises',
        queryParameters: {
          if (filters.search != null && filters.search!.isNotEmpty)
            'search': filters.search,
          if (filters.muscleGroupSlug != null)
            'muscleGroup': filters.muscleGroupSlug,
          if (filters.difficulty != null)
            'difficulty': filters.difficulty!.apiValue,
          if (cursor != null) 'cursor': cursor,
        },
      );

      final body = response.data ?? const <String, dynamic>{};
      final items = (body['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(exerciseSummaryFromJson)
          .toList();
      final meta = body['meta'] as Map<String, dynamic>? ?? const {};

      return ExercisesPage(
        items: items,
        nextCursor: meta['nextCursor'] as String?,
        hasMore: meta['hasMore'] as bool? ?? false,
      );
    });
  }

  @override
  Future<ExerciseDetail> byIdOrSlug(String idOrSlug) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/exercises/$idOrSlug');
      return exerciseDetailFromJson(
        response.data?['data'] as Map<String, dynamic>? ?? const {},
      );
    });
  }

  @override
  Future<List<MuscleGroupRef>> muscleGroups() {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/muscle-groups');
      return (response.data?['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(muscleGroupFromJson)
          .toList();
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

final exercisesRepositoryProvider = Provider<ExercisesRepository>((ref) {
  return ExercisesRepositoryImpl(ref.watch(dioProvider));
});
