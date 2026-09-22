import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/domain/repositories/progress_repository.dart';

/// Minuit UTC d'il y a [jours] jours.
///
/// LA RÈGLE DE CE FICHIER, et de tout décor : une date RENDUE À L'ÉCRAN se
/// date relativement à maintenant. Une date seulement utilisée comme
/// identifiant peut rester figée ; celle qu'un écran transforme en « IL Y A
/// 1 MOIS » ou qu'il compare à la semaine en cours, non — elle vieillit, et
/// le décor finit par raconter le contraire de ce qu'il illustre.
DateTime _ilYA(int jours) {
  final maintenant = DateTime.now().toUtc();
  return DateTime.utc(
    maintenant.year,
    maintenant.month,
    maintenant.day - jours,
  );
}

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
        // Avant-hier et hier, PAS deux jours d'août figés : la carte
        // s'intitule « Volume hebdo » et se légende « sur la semaine », et
        // elle datait son axe de sept semaines plus tôt. Elle se
        // contredisait donc dans son propre cadre.
        //
        // Ces deux jours peuvent tomber de part et d'autre d'un lundi, donc
        // sur DEUX semaines ISO — et l'assiduité devient alors calculable,
        // ce qui remplace la tuile de durée. C'est le comportement JUSTE de
        // l'application ; une épreuve qui vise l'une des deux tuiles pose
        // donc ses propres points avec [pointsMemeSemaine].
        ProgressPoint(bucketStart: _ilYA(2), sessionsCount: 1, volumeKg: 840),
        ProgressPoint(bucketStart: _ilYA(1), sessionsCount: 1, volumeKg: 700),
      ],
);

/// Deux points garantis dans la MÊME semaine ISO.
///
/// `weeklyAttendance` rend `null` sous deux semaines couvertes — « une
/// assiduité sur une seule semaine vaudrait mécaniquement 100 % » — et c'est
/// ce qui décide entre la tuile de durée et celle d'assiduité. Une épreuve
/// qui vise l'une des deux doit donc fixer la semaine, pas la subir.
List<ProgressPoint> pointsMemeSemaine({
  double premier = 840,
  double second = 700,
}) {
  final maintenant = DateTime.now().toUtc();
  final lundi = DateTime.utc(
    maintenant.year,
    maintenant.month,
    maintenant.day - (maintenant.weekday - 1),
  );
  return [
    ProgressPoint(bucketStart: lundi, sessionsCount: 1, volumeKg: premier),
    ProgressPoint(
      bucketStart: lundi.add(const Duration(days: 1)),
      sessionsCount: 1,
      volumeKg: second,
    ),
  ];
}

/// Un record, daté RELATIVEMENT à maintenant.
///
/// La date était figée au 6 août 2026, et l'écran la rend en âge :
/// `record_row.dart` écrit « IL Y A 1 MOIS », puis « IL Y A 2 MOIS », et
/// ainsi de suite. La galerie montrait donc quelqu'un qui s'entraîne tous
/// les jours et n'a plus battu un record depuis des semaines — l'inverse de
/// ce que l'écran Progrès raconte. Même défaut, même remède que
/// `historyOf()` : une date figée dans un décor vieillit, un décalage non.
///
/// [joursAvant] distingue les records entre eux : quatre entrées à la
/// seconde près se lisent comme une donnée fabriquée, et le plus récent doit
/// pouvoir porter son accent.
PersonalRecordEntry recordOf(
  String exerciseName,
  PersonalRecordType type,
  double value, {
  int joursAvant = 3,
}) => PersonalRecordEntry(
  id: '$exerciseName-${type.apiValue}',
  exerciseName: exerciseName,
  type: type,
  value: value,
  achievedAt: DateTime.now().toUtc().subtract(Duration(days: joursAvant)),
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

  /// Ce que le « serveur » compte sur la vie entière.
  ///
  /// `null` par défaut : la plupart des tests n'en ont que faire, et le
  /// moteur retombe alors sur l'historique local, comme hors ligne.
  LifetimeStats? lifetime;

  @override
  Future<LifetimeStats> lifetimeStats() async {
    final servi = lifetime;
    if (servi == null) {
      // Même forme que le serveur muet : le provider passe en erreur, et la
      // dérivation locale reprend la main.
      throw Exception('Compteurs de vie entière indisponibles.');
    }
    return servi;
  }

  /// La frise, pilotable : une liste plate, paginée comme le serveur.
  final List<ProgressEvent> timelineEvents = [];

  /// Bascule pour éprouver l'écran hors ligne, page initiale ou suivante.
  bool timelineFails = false;

  /// Ce qui a été remonté du journal local — prouve qu'un écran POUSSE ses
  /// récompenses au lieu de les garder pour lui.
  final List<Map<String, DateTime>> pushedMilestones = [];

  @override
  Future<ProgressTimelinePage> timeline({
    int limit = 30,
    String? cursor,
    List<ProgressEventKind> kinds = const [],
  }) async {
    if (timelineFails) {
      throw Exception('Frise indisponible.');
    }
    final retenus = kinds.isEmpty
        ? timelineEvents
        : timelineEvents.where((event) => kinds.contains(event.kind)).toList();
    // Le curseur est l'INDEX de reprise : la doublure n'a pas à reproduire
    // l'encodage du serveur, seulement sa promesse — ni saut, ni rejeu.
    final depuis = cursor == null ? 0 : int.parse(cursor);
    final page = retenus.skip(depuis).take(limit).toList(growable: false);
    final suite = depuis + page.length;
    return ProgressTimelinePage(
      items: page,
      hasMore: suite < retenus.length,
      nextCursor: suite < retenus.length ? '$suite' : null,
    );
  }

  @override
  Future<void> pushMilestones(Map<String, DateTime> rewards) async {
    pushedMilestones.add(Map.of(rewards));
  }

  @override
  Future<void> deleteBodyMetric(String id) async {
    removedMetricIds.add(id);
    _bodyMetrics.removeWhere((metric) => metric.id == id);
  }
}
