import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/account_bound_cache.dart';
import '../../../authentication/presentation/providers/keep_for_account.dart';
import '../../data/repositories/progress_repository_impl.dart';
import '../../domain/entities/progress.dart';

/// Période sélectionnée pour les statistiques.
final progressPeriodProvider = StateProvider.autoDispose<ProgressPeriod>(
  (ref) => ProgressPeriod.week,
);

/// Statistiques agrégées d'UNE période, gardées deux minutes : l'accueil
/// (la semaine) et l'onglet Progrès lisent la même, et revenir sur une
/// période déjà vue ne la redemande plus.
final overviewForPeriodProvider = FutureProvider.autoDispose
    .family<ProgressOverviewEntity, ProgressPeriod>((ref, period) {
      return keepForAccount(
        ref,
        () => ref.watch(progressRepositoryProvider).overview(period),
      );
    });

/// Statistiques agrégées de la période sélectionnée.
final progressOverviewProvider =
    FutureProvider.autoDispose<ProgressOverviewEntity>((ref) {
      final period = ref.watch(progressPeriodProvider);
      return ref.watch(overviewForPeriodProvider(period).future);
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

/// Les MENSURATIONS, zone par zone (chaque liste du plus ancien au plus
/// récent). Une zone jamais mesurée a sa liste vide : c'est la section qui
/// décide de ne pas la montrer.
final bodyMeasurementsProvider =
    FutureProvider.autoDispose<Map<BodyMetricKind, List<BodyMetricEntry>>>((
      ref,
    ) async {
      final repository = ref.watch(progressRepositoryProvider);
      const kinds = BodyMetricKind.measurements;
      // ponytail: une requête par zone (sept, en parallèle, sur l'index
      // `(userId, metricType, measuredAt)`) ; une route groupée si ça pèse.
      final lists = await Future.wait([
        for (final kind in kinds) repository.bodyMetrics(kind: kind),
      ]);
      return {for (final (i, kind) in kinds.indexed) kind: lists[i]};
    });

/// Les mesures d'UN type, telles que la feuille d'historique les liste : le
/// poids a sa source, les mensurations la leur.
final bodyMetricsOfKindProvider = Provider.autoDispose
    .family<List<BodyMetricEntry>, BodyMetricKind>((ref, kind) {
      if (kind.isMeasurement) {
        return ref.watch(bodyMeasurementsProvider).valueOrNull?[kind] ??
            const [];
      }
      return ref.watch(bodyWeightMetricsProvider).valueOrNull ?? const [];
    });

/// Actions sur les mesures corporelles, avec rafraîchissement des listes.
class BodyMetricActions {
  const BodyMetricActions(this._ref);

  final Ref _ref;

  Future<void> add(
    BodyMetricKind kind,
    double value, {
    DateTime? measuredAt,
  }) async {
    await _ref
        .read(progressRepositoryProvider)
        .addBodyMetric(
          kind: kind,
          value: value,
          measuredAt: measuredAt ?? DateTime.now().toUtc(),
        );
    _refresh(kind);
  }

  /// Corrige une mesure déjà enregistrée.
  ///
  /// À SAVOIR : le dernier poids non supprimé nourrit le rapport métabolique
  /// (métabolisme de base, dépense, cible calorique). Corriger une valeur
  /// change donc les objectifs nutritionnels ; corriger une DATE peut changer
  /// quelle mesure fait foi. C'est voulu, et c'est pourquoi l'écran le dit.
  /// Une mensuration, elle, ne nourrit que sa courbe.
  Future<void> correct(
    BodyMetricEntry entry, {
    double? value,
    DateTime? measuredAt,
  }) async {
    await _ref
        .read(progressRepositoryProvider)
        .updateBodyMetric(
          id: entry.id,
          value: value,
          measuredAt: measuredAt?.toUtc(),
        );
    _refresh(entry.kind);
  }

  Future<void> remove(BodyMetricEntry entry) async {
    await _ref.read(progressRepositoryProvider).deleteBodyMetric(entry.id);
    _refresh(entry.kind);
  }

  /// Seule la liste touchée se relit : une pesée ne relance pas les sept
  /// requêtes des mensurations.
  void _refresh(BodyMetricKind kind) => _ref.invalidate(
    kind.isMeasurement ? bodyMeasurementsProvider : bodyWeightMetricsProvider,
  );
}

final bodyMetricActionsProvider = Provider<BodyMetricActions>(
  BodyMetricActions.new,
);
