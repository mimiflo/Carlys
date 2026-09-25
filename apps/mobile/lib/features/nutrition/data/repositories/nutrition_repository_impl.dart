import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/nutrition.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../mappers/meal_mappers.dart';
import '../mappers/metabolism_mappers.dart';

class NutritionRepositoryImpl implements NutritionRepository {
  NutritionRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<MetabolismReport> metabolismReport() {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/nutrition/metabolism',
      );
      final body = response.data?['data'] as Map<String, dynamic>? ?? const {};

      return MetabolismReport(
        profile: metabolicProfileFromJson(
          body['profile'] as Map<String, dynamic>? ?? const {},
        ),
        missing: missingFieldsFromJson(body['missing'] as List<dynamic>?),
        metabolism: metabolismResultFromJson(
          body['metabolism'] as Map<String, dynamic>?,
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
          .whereType<Map<String, dynamic>>()
          .map(mealFromJson)
          .toList(growable: false);
    });
  }

  @override
  Future<MealDetail> meal(String id) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/nutrition/meals/$id',
      );
      return (
        meal: mealFromJson(_data(response)),
        attribution: attributionFromMeta(response.data?['meta']),
      );
    });
  }

  @override
  Future<MealEntry> addMeal(String id, MealWrite write) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/nutrition/meals',
        data: mealCreationBody(id, write),
      );
      return mealFromJson(_data(response));
    });
  }

  @override
  Future<MealEntry> updateMeal(String id, MealWrite write) {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/nutrition/meals/$id',
        data: mealCorrectionBody(write),
      );
      return mealFromJson(_data(response));
    });
  }

  @override
  Future<void> deleteMeal(String id) {
    return _guard(() async {
      await _dio.delete<Map<String, dynamic>>('/nutrition/meals/$id');
    });
  }

  @override
  Future<FoodSearchResult> searchFoods(String query, {int limit = 20}) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/nutrition/foods',
        queryParameters: {'q': query, 'limit': limit},
      );
      final rows = response.data?['data'] as List<dynamic>? ?? const [];
      return (
        foods: rows
            .whereType<Map<String, dynamic>>()
            .map(foodFromJson)
            .toList(growable: false),
        source: foodSourceFromMeta(response.data?['meta']),
      );
    });
  }

  @override
  Future<FoodDetail> food(int code) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/nutrition/foods/$code',
      );
      return (
        food: foodFromJson(_data(response)),
        source: foodSourceFromMeta(response.data?['meta']),
      );
    });
  }

  @override
  Future<Uint8List?> mealPhoto(String id) async {
    try {
      return await _guard(() async {
        final response = await _dio.get<List<int>>(
          '/nutrition/meals/$id/photo',
          // La réponse est l'image elle-même, sans enveloppe JSON.
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = response.data;
        return bytes == null || bytes.isEmpty
            ? null
            : Uint8List.fromList(bytes);
      });
    } on ServerException catch (error) {
      // 404 : pas de photo (ou plus de repas) — un repli, pas une panne.
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<MealEntry> replaceMealPhoto(String id, Uint8List jpeg) {
    return _guard(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/nutrition/meals/$id/photo',
        data: _photoForm(jpeg),
      );
      return mealFromJson(_data(response));
    });
  }

  @override
  Future<void> removeMealPhoto(String id) {
    return _guard(() async {
      await _dio.delete<void>('/nutrition/meals/$id/photo');
    });
  }

  /// Le corps d'un `PUT …/photo` : UN fichier, dans le champ « file »,
  /// déclaré `image/jpeg`, et rien d'autre (le serveur refuse tout champ
  /// texte à côté). Le nom est neutre : il ne dit rien de l'appareil ni de
  /// la galerie, et le serveur ne le garde pas.
  static FormData _photoForm(Uint8List jpeg) => FormData.fromMap({
    'file': MultipartFile.fromBytes(
      jpeg,
      filename: 'photo.jpg',
      contentType: DioMediaType('image', 'jpeg'),
    ),
  });

  /// La charge utile d'une réponse enveloppée (`{ data, meta, requestId }`).
  static Map<String, dynamic> _data(Response<Map<String, dynamic>> response) =>
      response.data?['data'] as Map<String, dynamic>? ?? const {};

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
