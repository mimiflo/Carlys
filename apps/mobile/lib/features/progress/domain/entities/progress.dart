/// Entités du domaine progression (immuables, écrites à la main).
library;

/// Période d'analyse des statistiques.
enum ProgressPeriod {
  week('week', 'Semaine'),
  month('month', 'Mois'),
  year('year', 'Année');

  const ProgressPeriod(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Point de graphique : volume soulevé sur un intervalle.
class ProgressPoint {
  const ProgressPoint({
    required this.bucketStart,
    required this.sessionsCount,
    required this.volumeKg,
  });

  final DateTime bucketStart;
  final int sessionsCount;
  final double volumeKg;
}

/// Statistiques agrégées d'une période.
class ProgressOverviewEntity {
  const ProgressOverviewEntity({
    required this.period,
    required this.sessionsCount,
    required this.setsCount,
    required this.totalVolumeKg,
    required this.totalDurationSeconds,
    required this.points,
  });

  final ProgressPeriod period;
  final int sessionsCount;
  final int setsCount;
  final double totalVolumeKg;
  final int totalDurationSeconds;
  final List<ProgressPoint> points;
}

enum PersonalRecordType {
  maxWeight('MAX_WEIGHT', 'Charge max'),
  maxReps('MAX_REPS', 'Répétitions max'),
  maxSetVolume('MAX_SET_VOLUME', 'Volume max sur une série');

  const PersonalRecordType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PersonalRecordType fromApi(String value) =>
      PersonalRecordType.values.firstWhere(
        (type) => type.apiValue == value,
        orElse: () => PersonalRecordType.maxWeight,
      );
}

/// Record personnel sur un exercice.
class PersonalRecordEntry {
  const PersonalRecordEntry({
    required this.id,
    required this.exerciseName,
    required this.type,
    required this.value,
    required this.achievedAt,
    this.exerciseId,
    this.reps,
    this.weightKg,
  });

  final String id;
  final String? exerciseId;
  final String exerciseName;
  final PersonalRecordType type;

  /// kg, répétitions ou kg de volume selon [type].
  final double value;
  final int? reps;
  final double? weightKg;
  final DateTime achievedAt;

  String get formattedValue {
    final rounded = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return type == PersonalRecordType.maxReps ? '$rounded rép.' : '$rounded kg';
  }
}

enum BodyMetricKind {
  weightKg('WEIGHT_KG', 'Poids (kg)'),
  bodyFatPercent('BODY_FAT_PERCENT', 'Masse grasse (%)');

  const BodyMetricKind(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static BodyMetricKind fromApi(String value) =>
      BodyMetricKind.values.firstWhere(
        (kind) => kind.apiValue == value,
        orElse: () => BodyMetricKind.weightKg,
      );
}

/// Mesure corporelle datée (poids, masse grasse…).
class BodyMetricEntry {
  const BodyMetricEntry({
    required this.id,
    required this.kind,
    required this.value,
    required this.measuredAt,
  });

  final String id;
  final BodyMetricKind kind;
  final double value;
  final DateTime measuredAt;
}
