import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/account_bound_cache.dart';
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
///
/// Un cache DE COMPTE ([AccountBoundCache]) : la vitrine, les faits des
/// récompenses et l'accueil le lisent par `valueOrNull`, et c'est là que
/// les records d'un compte parti se montraient au suivant. Permanent : deux
/// `Provider` permanents l'épinglaient déjà dès l'accueil, son `autoDispose`
/// ne le détruisait jamais.
final personalRecordsProvider = accountBoundCache<List<PersonalRecordEntry>>(
  (ref) => ref.watch(progressRepositoryProvider).records(),
  none: const [],
);

/// Ce que la vie entière compte, pour les récompenses.
///
/// Permanent, comme `earnedRewardsProvider` qui en dépend : le relire à
/// chaque navigation ferait clignoter les récompenses. Et cache DE COMPTE
/// ([AccountBoundCache]) : ses 200 séances ne passent pas au compte suivant.
final lifetimeStatsProvider = accountBoundCache<LifetimeStats>(
  (ref) => ref.watch(progressRepositoryProvider).lifetimeStats(),
  none: const LifetimeStats(completedSessions: 0, weeks: []),
);

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

  /// Corrige une mesure déjà enregistrée.
  ///
  /// À SAVOIR : le dernier poids non supprimé nourrit le rapport métabolique
  /// (métabolisme de base, dépense, cible calorique). Corriger une valeur
  /// change donc les objectifs nutritionnels ; corriger une DATE peut changer
  /// quelle mesure fait foi. C'est voulu, et c'est pourquoi l'écran le dit.
  Future<void> correct(
    String id, {
    double? valueKg,
    DateTime? measuredAt,
  }) async {
    await _ref
        .read(progressRepositoryProvider)
        .updateBodyMetric(
          id: id,
          value: valueKg,
          measuredAt: measuredAt?.toUtc(),
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
