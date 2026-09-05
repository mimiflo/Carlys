/// DTO de la progression — parsing manuel du JSON de l'API.
library;

import '../../domain/entities/progress.dart';

ProgressPoint progressPointFromJson(Map<String, dynamic> json) => ProgressPoint(
  bucketStart: DateTime.parse(json['bucketStart'] as String),
  sessionsCount: (json['sessionsCount'] as num).toInt(),
  volumeKg: (json['volumeKg'] as num).toDouble(),
);

ProgressOverviewEntity progressOverviewFromJson(Map<String, dynamic> json) =>
    ProgressOverviewEntity(
      period: ProgressPeriod.values.firstWhere(
        (period) => period.apiValue == json['period'],
        orElse: () => ProgressPeriod.week,
      ),
      sessionsCount: (json['sessionsCount'] as num).toInt(),
      setsCount: (json['setsCount'] as num).toInt(),
      totalVolumeKg: (json['totalVolumeKg'] as num).toDouble(),
      totalDurationSeconds: (json['totalDurationSeconds'] as num).toInt(),
      points: (json['points'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(progressPointFromJson)
          .toList(),
    );

PersonalRecordEntry personalRecordFromJson(Map<String, dynamic> json) =>
    PersonalRecordEntry(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String?,
      exerciseName: json['exerciseName'] as String,
      type: PersonalRecordType.fromApi(json['recordType'] as String),
      value: (json['value'] as num).toDouble(),
      reps: (json['reps'] as num?)?.toInt(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      achievedAt: DateTime.parse(json['achievedAt'] as String),
    );

BodyMetricEntry bodyMetricFromJson(Map<String, dynamic> json) =>
    BodyMetricEntry(
      id: json['id'] as String,
      kind: BodyMetricKind.fromApi(json['metricType'] as String),
      value: (json['value'] as num).toDouble(),
      measuredAt: DateTime.parse(json['measuredAt'] as String),
    );
