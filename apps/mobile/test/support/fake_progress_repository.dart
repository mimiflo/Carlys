import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/domain/repositories/progress_repository.dart';

ProgressOverviewEntity overviewOf(
  ProgressPeriod period, {
  int sessionsCount = 2,
  int setsCount = 6,
  double totalVolumeKg = 1540,
  int totalDurationSeconds = 5400,
  List<ProgressPoint>? points,
}) =>
    ProgressOverviewEntity(
      period: period,
      sessionsCount: sessionsCount,
      setsCount: setsCount,
      totalVolumeKg: totalVolumeKg,
      totalDurationSeconds: totalDurationSeconds,
      points: points ??
          [
            ProgressPoint(
              bucketStart: DateTime.utc(2026, 8, 5),
              sessionsCount: 1,
              volumeKg: 840,
            ),
            ProgressPoint(
              bucketStart: DateTime.utc(2026, 8, 6),
              sessionsCount: 1,
              volumeKg: 700,
            ),
          ],
    );

PersonalRecordEntry recordOf(
  String exerciseName,
  PersonalRecordType type,
  double value,
) =>
    PersonalRecordEntry(
      id: '$exerciseName-${type.apiValue}',
      exerciseName: exerciseName,
      type: type,
      value: value,
      achievedAt: DateTime.utc(2026, 8, 6, 10),
    );

/// ProgressRepository de test — données en mémoire, aucune requête réseau.
class FakeProgressRepository implements ProgressRepository {
  FakeProgressRepository({
    List<PersonalRecordEntry>? records,
    List<BodyMetricEntry>? bodyMetrics,
  })  : _records = records ?? const [],
        _bodyMetrics = [...?bodyMetrics];

  final List<PersonalRecordEntry> _records;
  final List<BodyMetricEntry> _bodyMetrics;
  final List<ProgressPeriod> requestedPeriods = [];
  int _nextId = 0;

  @override
  Future<ProgressOverviewEntity> overview(ProgressPeriod period) async {
    requestedPeriods.add(period);
    return overviewOf(period);
  }

  @override
  Future<List<PersonalRecordEntry>> records() async => _records;

  @override
  Future<List<BodyMetricEntry>> bodyMetrics({
    BodyMetricKind kind = BodyMetricKind.weightKg,
    int limit = 90,
  }) async {
    return _bodyMetrics.where((metric) => metric.kind == kind).toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  }

  @override
  Future<BodyMetricEntry> addBodyMetric({
    required BodyMetricKind kind,
    required double value,
    required DateTime measuredAt,
  }) async {
    final metric = BodyMetricEntry(
      id: 'metric-${_nextId++}',
      kind: kind,
      value: value,
      measuredAt: measuredAt,
    );
    _bodyMetrics.add(metric);
    return metric;
  }

  @override
  Future<void> deleteBodyMetric(String id) async {
    _bodyMetrics.removeWhere((metric) => metric.id == id);
  }
}
