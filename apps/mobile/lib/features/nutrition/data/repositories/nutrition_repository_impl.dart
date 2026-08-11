import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/nutrition.dart';
import '../../domain/repositories/nutrition_repository.dart';

class NutritionRepositoryImpl implements NutritionRepository {
  NutritionRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<MetabolismReport> metabolismReport() {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/nutrition/metabolism');
      final body = response.data?['data'] as Map<String, dynamic>? ?? const {};
      final profile = body['profile'] as Map<String, dynamic>? ?? const {};
      final metabolism = body['metabolism'] as Map<String, dynamic>?;

      return MetabolismReport(
        profile: MetabolicProfile(
          sex: BiologicalSex.fromApi(profile['sex'] as String?),
          birthDate: profile['birthDate'] == null
              ? null
              : DateTime.parse(profile['birthDate'] as String),
          ageYears: (profile['ageYears'] as num?)?.toInt(),
          heightCm: (profile['heightCm'] as num?)?.toDouble(),
          weightKg: (profile['weightKg'] as num?)?.toDouble(),
          activityLevel:
              ActivityLevel.fromApi(profile['activityLevel'] as String?),
          goal: NutritionGoal.fromApi(profile['goal'] as String?),
        ),
        missing: (body['missing'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map(MetabolismMissingField.fromApi)
            .whereType<MetabolismMissingField>()
            .toList(),
        metabolism: metabolism == null
            ? null
            : MetabolismResult(
                bmi: (metabolism['bmi'] as num).toDouble(),
                bmiCategory:
                    BmiCategory.fromApi(metabolism['bmiCategory'] as String),
                bmrKcal: (metabolism['bmrKcal'] as num).toInt(),
                tdeeKcal: (metabolism['tdeeKcal'] as num).toInt(),
                targetKcal: (metabolism['targetKcal'] as num).toInt(),
                proteinG: (metabolism['proteinG'] as num).toInt(),
                fatG: (metabolism['fatG'] as num).toInt(),
                carbsG: (metabolism['carbsG'] as num).toInt(),
                waterMl: (metabolism['waterMl'] as num).toInt(),
              ),
      );
    });
  }

  @override
  Future<void> updateProfile(MetabolicProfileUpdate update) {
    return _guard(() async {
      final payload = <String, dynamic>{
        if (update.sex != null) 'sex': update.sex!.apiValue,
        if (update.birthDate != null)
          'birthDate': update.birthDate!.toUtc().toIso8601String(),
        if (update.heightCm != null) 'heightCm': update.heightCm,
        if (update.activityLevel != null)
          'activityLevel': update.activityLevel!.apiValue,
        if (update.goal != null) 'nutritionGoal': update.goal!.apiValue,
      };
      if (payload.isEmpty) {
        return;
      }
      await _dio.patch<Map<String, dynamic>>('/users/me', data: payload);
    });
  }

  @override
  Future<List<MealEntry>> mealsBetween(DateTime from, DateTime to) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/nutrition/meals',
        queryParameters: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
      );
      final rows = response.data?['data'] as List<dynamic>? ?? const [];
      return rows
          .cast<Map<String, dynamic>>()
          .map(_meal)
          .toList(growable: false);
    });
  }

  @override
  Future<MealEntry> addMeal(MealEntry meal) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/nutrition/meals',
        data: {
          'id': meal.id,
          'name': meal.name,
          'kcal': meal.kcal,
          if (meal.proteinG != null) 'proteinG': meal.proteinG,
          'eatenAt': meal.eatenAt.toUtc().toIso8601String(),
        },
      );
      final body = response.data?['data'] as Map<String, dynamic>? ?? const {};
      return _meal(body);
    });
  }

  @override
  Future<void> deleteMeal(String id) {
    return _guard(() async {
      await _dio.delete<Map<String, dynamic>>('/nutrition/meals/$id');
    });
  }

  MealEntry _meal(Map<String, dynamic> row) {
    return MealEntry(
      id: row['id'] as String,
      name: row['name'] as String,
      kcal: (row['kcal'] as num).toInt(),
      proteinG: (row['proteinG'] as num?)?.toInt(),
      eatenAt: DateTime.parse(row['eatenAt'] as String),
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  return NutritionRepositoryImpl(ref.watch(dioProvider));
});
