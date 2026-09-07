/// Progression de la DÉMONSTRATION (flavor `demo`) — aucun réseau.
library;

import '../features/progress/domain/entities/progress.dart';
import '../features/progress/domain/repositories/progress_repository.dart';
import 'demo_data.dart';

/// Statistiques figées par période ; mesures corporelles modifiables.
class DemoProgressRepository implements ProgressRepository {
  final List<BodyMetricEntry> _metrics = [...demoWeights];
  int _nextId = 0;

  @override
  Future<ProgressOverviewEntity> overview(ProgressPeriod period) async {
    final (sessions, sets, volume, duration, buckets) = switch (period) {
      ProgressPeriod.week => (4, 58, 6420.0, 4 * 3300, 7),
      ProgressPeriod.month => (14, 196, 22850.0, 14 * 3300, 5),
      ProgressPeriod.year => (86, 1180, 131400.0, 86 * 3300, 12),
    };
    final perBucket = volume / buckets;
    return ProgressOverviewEntity(
      period: period,
      sessionsCount: sessions,
      setsCount: sets,
      totalVolumeKg: volume,
      totalDurationSeconds: duration,
      points: [
        for (var i = 0; i < buckets; i++)
          ProgressPoint(
            bucketStart: DateTime.now().toUtc().subtract(
              Duration(days: buckets - i),
            ),
            sessionsCount: 1,
            // Variation déterministe autour de la moyenne (pas d'aléatoire).
            volumeKg: perBucket * (0.7 + 0.6 * ((i * 37) % 10) / 10),
          ),
      ],
    );
  }

  @override
  Future<List<PersonalRecordEntry>> records() async => demoRecords;

  @override
  Future<List<BodyMetricEntry>> bodyMetrics({
    BodyMetricKind kind = BodyMetricKind.weightKg,
    int limit = 90,
  }) async {
    return _metrics.where((metric) => metric.kind == kind).toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  }

  @override
  Future<BodyMetricEntry> addBodyMetric({
    required BodyMetricKind kind,
    required double value,
    required DateTime measuredAt,
  }) async {
    final metric = BodyMetricEntry(
      id: 'demo-added-${_nextId++}',
      kind: kind,
      value: value,
      measuredAt: measuredAt,
    );
    _metrics.add(metric);
    return metric;
  }

  @override
  Future<void> deleteBodyMetric(String id) async {
    _metrics.removeWhere((metric) => metric.id == id);
  }
}
