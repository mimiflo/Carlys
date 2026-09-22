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

/// Un point de la progression sur UN exercice : une séance, sa meilleure
/// charge et son volume.
///
/// Le serveur sert `maxWeightKg` et `maxReps` à `null` quand la séance n'a
/// porté aucune charge (poids du corps, cardio) : l'absence se dit, elle ne
/// se remplace pas par un zéro qui ressemblerait à un échec.
class ExerciseProgressionPoint {
  const ExerciseProgressionPoint({
    required this.sessionId,
    required this.date,
    required this.volumeKg,
    this.maxWeightKg,
    this.maxReps,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
  });

  final String sessionId;
  final DateTime date;
  final double volumeKg;
  final double? maxWeightKg;
  final int? maxReps;

  /// Ce que la séance a parcouru et chronométré sur cet exercice, SOMMÉ :
  /// trois fractionnés de 400 m font 1 200 m de course. Zéro sur un
  /// exercice de fonte, ce qui est exact.
  final int distanceMeters;
  final int durationSeconds;

  /// Vrai quand la séance a laissé une trace de cardio.
  bool get hasCardio => distanceMeters > 0 || durationSeconds > 0;
}

/// La progression sur un exercice : ses séances ET ses records, ensemble.
///
/// Les deux arrivent dans la même réponse parce qu'ils se lisent ensemble :
/// un record est un point de la courbe, pas une liste à côté.
class ExerciseProgressionEntity {
  const ExerciseProgressionEntity({
    required this.exerciseId,
    required this.exerciseName,
    required this.records,
    required this.points,
  });

  final String exerciseId;
  final String exerciseName;
  final List<PersonalRecordEntry> records;

  /// Du plus ancien au plus récent, prêts pour un tracé.
  final List<ExerciseProgressionPoint> points;

  /// Séances où une charge a été notée : les seules traçables en kilos.
  List<ExerciseProgressionPoint> get chargedPoints =>
      points.where((point) => point.maxWeightKg != null).toList();

  /// Séances où une distance ou un chrono a été noté.
  List<ExerciseProgressionPoint> get cardioPoints =>
      points.where((point) => point.hasCardio).toList();

  /// Ce que cet exercice raconte le mieux : des kilos, ou des kilomètres.
  ///
  /// Le choix se fait sur les FAITS, pas sur une étiquette d'exercice : une
  /// fiche mal catégorisée n'a alors aucune conséquence, et un exercice
  /// hybride (le rameur chargé, la marche lestée) suit ce qu'on y a
  /// réellement noté. À égalité, la charge l'emporte — c'est le cœur de
  /// l'application.
  bool get readsAsCardio => cardioPoints.length > chargedPoints.length;

  /// Ce qu'une courbe cardio trace : la distance quand elle est notée au
  /// moins aussi souvent que le chrono, le temps sinon.
  ///
  /// La distance l'emporte à égalité parce qu'elle dit la performance : un
  /// coureur qui met le même temps sur plus de kilomètres progresse, et
  /// l'inverse ne se lit pas.
  CardioReading get cardioReading {
    final avecDistance = cardioPoints
        .where((point) => point.distanceMeters > 0)
        .length;
    final avecChrono = cardioPoints
        .where((point) => point.durationSeconds > 0)
        .length;
    return avecDistance >= avecChrono
        ? CardioReading.distance
        : CardioReading.duration;
  }
}

/// Ce qu'une courbe cardio met en ordonnée.
enum CardioReading { distance, duration }
