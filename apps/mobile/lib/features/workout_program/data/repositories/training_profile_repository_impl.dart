import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/training_goal.dart';
import '../../domain/entities/training_profile.dart';
import '../../domain/repositories/training_profile_repository.dart';

/// Relecture d'une réponse `GET /users/me/training` — toute valeur
/// inconnue rend `null`, jamais une entrée devinée.
TrainingProfile trainingProfileFromJson(Map<String, dynamic> json) {
  return TrainingProfile(
    goal: TrainingGoal.fromWire(json['trainingGoal'] as String?),
    experience: TrainingExperience.fromWire(
      json['trainingExperience'] as String?,
    ),
    weeklySessionsTarget: json['weeklySessionsTarget'] as int?,
    sessionMinutesTarget: json['sessionMinutesTarget'] as int?,
    equipmentSlugs: (json['equipmentSlugs'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
  );
}

/// Entrées de génération servies par l'API : lecture dédiée, écritures sur
/// `PATCH /users/me` — le même guichet que le reste du profil.
class TrainingProfileRepositoryImpl implements TrainingProfileRepository {
  TrainingProfileRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<TrainingProfile> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/users/me/training',
      );
      final data = response.data?['data'] as Map<String, dynamic>? ?? const {};
      return trainingProfileFromJson(data);
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }

  @override
  Future<void> patch({
    TrainingExperience? experience,
    int? weeklySessionsTarget,
    int? sessionMinutesTarget,
    List<String>? equipmentSlugs,
  }) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/users/me',
        data: {
          if (experience != null) 'trainingExperience': experience.wire,
          if (weeklySessionsTarget != null)
            'weeklySessionsTarget': weeklySessionsTarget,
          if (sessionMinutesTarget != null)
            'sessionMinutesTarget': sessionMinutesTarget,
          if (equipmentSlugs != null) 'equipmentSlugs': equipmentSlugs,
        },
      );
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final trainingProfileRepositoryProvider = Provider<TrainingProfileRepository>(
  (ref) => TrainingProfileRepositoryImpl(ref.watch(dioProvider)),
);
