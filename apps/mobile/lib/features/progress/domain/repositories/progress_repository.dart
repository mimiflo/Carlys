import '../entities/progress.dart';

/// Accès aux données de progression (statistiques serveur).
abstract interface class ProgressRepository {
  Future<ProgressOverviewEntity> overview(ProgressPeriod period);

  Future<List<PersonalRecordEntry>> records();

  /// Mesures servies du plus ancien au plus récent (prêtes pour un graphique).
  Future<List<BodyMetricEntry>> bodyMetrics({
    BodyMetricKind kind = BodyMetricKind.weightKg,
    int limit = 90,
  });

  /// L'identifiant est généré côté client : la création est idempotente.
  Future<BodyMetricEntry> addBodyMetric({
    required BodyMetricKind kind,
    required double value,
    required DateTime measuredAt,
  });

  /// Corrige une mesure existante : la valeur, la date, ou les deux.
  ///
  /// Le TYPE ne se corrige pas — un poids ne devient pas un taux de masse
  /// grasse ; cette erreur-là se répare en supprimant puis recréant.
  ///
  /// Contrairement à la suppression, ce n'est PAS idempotent : corriger une
  /// mesure inconnue ou déjà supprimée échoue, pour que l'application ne
  /// laisse jamais croire qu'une correction est prise alors que la ligne ne
  /// compte plus.
  Future<BodyMetricEntry> updateBodyMetric({
    required String id,
    double? value,
    DateTime? measuredAt,
  });

  /// Idempotent : supprimer une mesure déjà supprimée aboutit.
  Future<void> deleteBodyMetric(String id);

  /// Progression sur UN exercice : ses séances et ses records, ensemble.
  ///
  /// La route existe et est testée côté serveur depuis septembre ; elle
  /// n'avait simplement aucun client.
  Future<ExerciseProgressionEntity> exerciseProgression(String exerciseId);

  /// Ce que la vie entière compte, pour les récompenses. Voir
  /// [LifetimeStats] : des faits, jamais une règle.
  Future<LifetimeStats> lifetimeStats();

  /// Une page de la FRISE, de la plus récente à la plus ancienne.
  ///
  /// [kinds] vide veut dire « tous » : une frise de deux ans sans filtre est
  /// illisible, et c'est aussi ce qui permet de n'afficher que les records.
  Future<ProgressTimelinePage> timeline({
    int limit,
    String? cursor,
    List<ProgressEventKind> kinds,
  });

  /// Remonte le journal de récompenses de CET appareil. La plus ANCIENNE
  /// date gagne côté serveur : deux appareils n'ont pas regardé le même
  /// jour, et le journal date du jour où l'application a regardé.
  Future<void> pushMilestones(Map<String, DateTime> rewards);
}
