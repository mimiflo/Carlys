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

  /// Idempotent : supprimer une mesure déjà supprimée aboutit.
  Future<void> deleteBodyMetric(String id);
}
