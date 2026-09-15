import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/domain/repositories/progress_repository.dart';

ProgressOverviewEntity overviewOf(
  ProgressPeriod period, {
  int sessionsCount = 2,
  int setsCount = 6,
  double totalVolumeKg = 1540,
  int totalDurationSeconds = 5400,
  List<ProgressPoint>? points,
}) => ProgressOverviewEntity(
  period: period,
  sessionsCount: sessionsCount,
  setsCount: setsCount,
  totalVolumeKg: totalVolumeKg,
  totalDurationSeconds: totalDurationSeconds,
  points:
      points ??
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
) => PersonalRecordEntry(
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
    this.overviewFor,
  }) : _records = records ?? const [],
       _bodyMetrics = [...?bodyMetrics];

  final List<PersonalRecordEntry> _records;
  final List<BodyMetricEntry> _bodyMetrics;
  final List<ProgressPeriod> requestedPeriods = [];
  int _nextId = 0;

  /// La synthèse renvoyée pour une période ; par défaut deux séances réelles
  /// (`overviewOf`). Un test du premier jour la remplace par des zéros.
  final ProgressOverviewEntity Function(ProgressPeriod period)? overviewFor;

  @override
  Future<ProgressOverviewEntity> overview(ProgressPeriod period) async {
    requestedPeriods.add(period);
    return overviewFor?.call(period) ?? overviewOf(period);
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
  Future<BodyMetricEntry> updateBodyMetric({
    required String id,
    double? value,
    DateTime? measuredAt,
  }) async {
    final index = _bodyMetrics.indexWhere((metric) => metric.id == id);
    // Le vrai dépôt refuse une mesure inconnue (404) : le faux le refuse
    // aussi, sinon un test passerait sur une correction qui n'a rien touché.
    if (index < 0) {
      throw StateError('Mesure $id introuvable');
    }
    final avant = _bodyMetrics[index];
    final apres = BodyMetricEntry(
      id: avant.id,
      kind: avant.kind,
      value: value ?? avant.value,
      measuredAt: measuredAt ?? avant.measuredAt,
    );
    _bodyMetrics[index] = apres;
    return apres;
  }

  /// Identifiants réellement supprimés, dans l'ordre.
  ///
  /// Sert à prouver qu'ANNULER une confirmation ne supprime rien : sans ce
  /// compteur, un test qui annule et voit la mesure toujours là ne saurait
  /// pas distinguer « rien n'a été demandé » de « la suppression a échoué ».
  final List<String> removedMetricIds = [];

  /// Progressions par exercice, indexées par identifiant.
  final Map<String, ExerciseProgressionEntity> exerciseProgressions = {};

  /// Identifiants réellement demandés : prouve qu'un écran interroge bien la
  /// route, au lieu de recomposer la courbe à partir d'autre chose.
  final List<String> requestedExerciseIds = [];

  @override
  Future<ExerciseProgressionEntity> exerciseProgression(
    String exerciseId,
  ) async {
    requestedExerciseIds.add(exerciseId);
    final trouve = exerciseProgressions[exerciseId];
    if (trouve == null) {
      throw Exception('Exercice introuvable : $exerciseId');
    }
    return trouve;
  }

  @override
  Future<void> deleteBodyMetric(String id) async {
    removedMetricIds.add(id);
    _bodyMetrics.removeWhere((metric) => metric.id == id);
  }
}
