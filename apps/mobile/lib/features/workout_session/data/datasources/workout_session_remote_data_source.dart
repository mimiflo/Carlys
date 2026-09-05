import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../dto/workout_session_dtos.dart';

/// Une page de `GET /api/v1/workout-sessions` (pagination par curseur).
class WorkoutSessionsPage {
  const WorkoutSessionsPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<RemoteWorkoutSessionRef> items;
  final String? nextCursor;
  final bool hasMore;
}

/// Lectures serveur des séances.
///
/// **Les écritures ne passent pas ici** : elles vont dans la file de
/// synchronisation (`SyncApi`), seul endroit où vivent le rejeu, le backoff et
/// l'idempotence. Cette source ne sert qu'à *rapatrier* ce que le serveur
/// détient — changement d'appareil ou réinstallation.
abstract interface class WorkoutSessionRemoteDataSource {
  Future<WorkoutSessionsPage> list({String? cursor, int? limit});

  Future<RemoteWorkoutSession> detail(String sessionId);
}

class DioWorkoutSessionRemoteDataSource
    implements WorkoutSessionRemoteDataSource {
  const DioWorkoutSessionRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<WorkoutSessionsPage> list({String? cursor, int? limit}) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/workout-sessions',
        queryParameters: {
          if (cursor != null) 'cursor': cursor,
          if (limit != null) 'limit': limit,
        },
      );

      final body = response.data ?? const <String, dynamic>{};
      final meta = body['meta'] as Map<String, dynamic>? ?? const {};
      return WorkoutSessionsPage(
        items: (body['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(sessionRefFromJson)
            .toList(),
        nextCursor: meta['nextCursor'] as String?,
        hasMore: meta['hasMore'] as bool? ?? false,
      );
    });
  }

  @override
  Future<RemoteWorkoutSession> detail(String sessionId) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/workout-sessions/$sessionId',
      );
      return sessionFromJson(
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

final workoutSessionRemoteDataSourceProvider =
    Provider<WorkoutSessionRemoteDataSource>((ref) {
      return DioWorkoutSessionRemoteDataSource(ref.watch(dioProvider));
    });
