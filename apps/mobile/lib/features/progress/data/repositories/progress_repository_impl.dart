import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../dto/progress_dtos.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl(this._dio, {this._uuid = const Uuid()});

  final Dio _dio;
  final Uuid _uuid;

  @override
  Future<ProgressOverviewEntity> overview(ProgressPeriod period) {
    return guardDio(() async {
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
    return guardDio(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/progress/records',
      );
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
    return guardDio(() async {
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
    String? id,
    required BodyMetricKind kind,
    required double value,
    required DateTime measuredAt,
  }) {
    return guardDio(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/body-metrics',
        data: {
          // Id né sur l'appareil : le serveur déduplique sur CET identifiant,
          // donc une même requête REJOUÉE ne crée pas de doublon.
          //  - Saisie : un v4 neuf à chaque geste. Resaisir après un échec
          //    est un autre geste, sous un autre identifiant ; aucun rejeu
          //    automatique (les mesures ne passent pas par la file hors
          //    ligne).
          //  - Import d'une pesée : le v5 DÉRIVÉ de la pesée (`id`), rejoué
          //    à chaque relecture. Le serveur le range dans l'espace du
          //    compte : l'id RENDU (stocké) n'est pas celui-ci.
          'id': id ?? _uuid.v4(),
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
  Future<BodyMetricEntry> updateBodyMetric({
    required String id,
    double? value,
    DateTime? measuredAt,
  }) {
    return guardDio(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/body-metrics/$id',
        // Seuls les champs RÉELLEMENT corrigés partent : le serveur laisse
        // les autres colonnes intactes. Envoyer `null` les écraserait.
        data: {
          if (value != null) 'value': value,
          if (measuredAt != null)
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
    return guardDio(() => _dio.delete<void>('/body-metrics/$id'));
  }

  @override
  Future<ExerciseProgressionEntity> exerciseProgression(String exerciseId) {
    return guardDio(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/progress/exercises/$exerciseId',
      );
      return exerciseProgressionFromJson(
        response.data?['data'] as Map<String, dynamic>? ?? const {},
      );
    });
  }

  @override
  Future<LifetimeStats> lifetimeStats() {
    return guardDio(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/progress/lifetime',
      );
      return lifetimeStatsFromJson(
        response.data?['data'] as Map<String, dynamic>? ?? const {},
      );
    });
  }

  @override
  Future<ProgressTimelinePage> timeline({
    int limit = 30,
    String? cursor,
    List<ProgressEventKind> kinds = const [],
  }) {
    return guardDio(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/progress/timeline',
        queryParameters: {
          'limit': limit,
          if (cursor != null) 'cursor': cursor,
          if (kinds.isNotEmpty)
            'kinds': kinds.map((kind) => kind.apiValue).join(','),
        },
      );
      return progressTimelineFromJson(
        response.data?['data'] as Map<String, dynamic>? ?? const {},
      );
    });
  }

  @override
  Future<void> pushMilestones(Map<String, DateTime> rewards) {
    return guardDio(() async {
      if (rewards.isEmpty) {
        return;
      }
      await _dio.post<void>(
        '/progress/milestones',
        data: {
          'milestones': [
            for (final entry in rewards.entries)
              {
                // Les titres sont des récompenses du même catalogue, mais la
                // frise les distingue : un franchissement de titre ne doit
                // pas produire AUSSI une ligne de récompense.
                'kind': entry.key.startsWith('titre-') ? 'TITLE' : 'REWARD',
                'key': entry.key,
                'occurredAt': entry.value.toUtc().toIso8601String(),
              },
          ],
        },
      );
    });
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepositoryImpl(ref.watch(dioProvider));
});
