import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/progress_repository_impl.dart';
import '../../domain/entities/progress.dart';

/// Période sélectionnée pour les statistiques.
final progressPeriodProvider = StateProvider.autoDispose<ProgressPeriod>(
  (ref) => ProgressPeriod.week,
);

/// Statistiques agrégées de la période sélectionnée.
final progressOverviewProvider =
    FutureProvider.autoDispose<ProgressOverviewEntity>((ref) {
      final period = ref.watch(progressPeriodProvider);
      return ref.watch(progressRepositoryProvider).overview(period);
    });

/// Records personnels, tous exercices confondus.
final personalRecordsProvider =
    FutureProvider.autoDispose<List<PersonalRecordEntry>>((ref) {
      return ref.watch(progressRepositoryProvider).records();
    });

/// Historique de poids corporel (du plus ancien au plus récent).
final bodyWeightMetricsProvider =
    FutureProvider.autoDispose<List<BodyMetricEntry>>((ref) {
      return ref.watch(progressRepositoryProvider).bodyMetrics();
    });

/// Actions sur les mesures corporelles, avec rafraîchissement de la liste.
class BodyMetricActions {
  const BodyMetricActions(this._ref);

  final Ref _ref;

  Future<void> addWeight(double valueKg, {DateTime? measuredAt}) async {
    await _ref
        .read(progressRepositoryProvider)
        .addBodyMetric(
          kind: BodyMetricKind.weightKg,
          value: valueKg,
          measuredAt: measuredAt ?? DateTime.now().toUtc(),
        );
    _ref.invalidate(bodyWeightMetricsProvider);
  }

  Future<void> remove(String id) async {
    await _ref.read(progressRepositoryProvider).deleteBodyMetric(id);
    _ref.invalidate(bodyWeightMetricsProvider);
  }
}

final bodyMetricActionsProvider = Provider<BodyMetricActions>(
  BodyMetricActions.new,
);
