import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/training_goal.dart';
import '../../domain/repositories/training_goal_repository.dart';

/// Objectif d'entraînement servi par l'API — le champ vit sur
/// `PATCH /users/me`, comme l'identité Carlys et la voix du Mentor.
class TrainingGoalRepositoryImpl implements TrainingGoalRepository {
  TrainingGoalRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> choose(TrainingGoal goal) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/users/me',
        data: {'trainingGoal': goal.wire},
      );
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final trainingGoalRepositoryProvider = Provider<TrainingGoalRepository>(
  (ref) => TrainingGoalRepositoryImpl(ref.watch(dioProvider)),
);
