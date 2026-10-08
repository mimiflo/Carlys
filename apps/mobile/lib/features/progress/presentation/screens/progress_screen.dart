import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../progression/presentation/widgets/progression_entry_card.dart';
import '../../domain/entities/progress.dart';
import '../providers/progress_providers.dart';
import '../widgets/body_weight_section.dart';
import '../widgets/progress_first_steps.dart';
import '../widgets/progress_header.dart';
import '../widgets/progress_tiles.dart';
import '../widgets/records_section.dart';
import '../widgets/volume_card.dart';

/// Progrès (maquette d'octobre 2026) : volume de la période, tuiles de
/// synthèse, porte du parcours, records personnels puis poids corporel.
///
/// Il a DEUX visages, et c'est la seule décision qu'il prend : quand les
/// trois sources ont répondu et n'ont rien (aucune séance sur la période,
/// aucun record, aucune mesure), il rend l'amorçage du premier jour à la
/// place de trois états vides empilés. Un compte neuf n'a rien à mesurer, il
/// a une porte à ouvrir.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(progressOverviewProvider);
    final firstDay = isFirstDay(
      overview: overview,
      records: ref.watch(personalRecordsProvider),
      metrics: ref.watch(bodyWeightMetricsProvider),
    );
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.gutter,
            AppSpacing.gutter,
            AppSpacing.gutter + bottomInset,
          ),
          children: [
            const ProgressHeader(),
            const SizedBox(height: AppSpacing.md),
            if (firstDay) ...[
              const ProgressFirstSteps(),
              const SizedBox(height: AppSpacing.md),
              // Le parcours a quelque chose à dire même le premier jour.
              const ProgressionEntryCard(),
            ] else ...[
              overview.when(
                loading: () => const AppLoadingIndicator(
                  label: 'Chargement des statistiques',
                ),
                error: (_, __) => AppErrorState(
                  title: 'Statistiques indisponibles',
                  message: AppErrorState.retryConnectionMessage,
                  onRetry: () => ref.invalidate(overviewForPeriodProvider),
                ),
                data: (data) => _OverviewBlock(overview: data),
              ),
              const SizedBox(height: AppSpacing.md),
              // La porte du parcours ne lit aucune donnée : elle s'affiche
              // même quand les statistiques, juste au-dessus, sont en erreur.
              const ProgressionEntryCard(),
              const SizedBox(height: AppSpacing.gapSection),
              const RecordsSection(),
              const SizedBox(height: AppSpacing.gapSection),
              const BodyWeightSection(),
            ],
          ],
        ),
      ),
    );
  }

  /// Le premier jour, et lui seul : les TROIS sources ont répondu, et
  /// aucune n'a rien. Une source encore en chargement ou en erreur ne
  /// suffit pas — un compte qui a des records mais aucune séance cette
  /// semaine n'est pas un compte neuf, et une panne n'est pas un vide.
  static bool isFirstDay({
    required AsyncValue<ProgressOverviewEntity> overview,
    required AsyncValue<List<PersonalRecordEntry>> records,
    required AsyncValue<List<BodyMetricEntry>> metrics,
  }) {
    bool empty<T>(AsyncValue<T> source, bool Function(T value) isEmpty) =>
        source.hasValue && !source.hasError && isEmpty(source.value as T);
    return empty(overview, (value) => value.points.isEmpty) &&
        empty(records, (value) => value.isEmpty) &&
        empty(metrics, (value) => value.isEmpty);
  }
}

/// Carte de volume + tuiles : quand aucune séance n'a été enregistrée sur la
/// période, l'état vide prend TOUTE la place — deux tuiles à zéro sous
/// « aucune séance » diraient la même chose une seconde fois, en chiffres.
class _OverviewBlock extends StatelessWidget {
  const _OverviewBlock({required this.overview});

  final ProgressOverviewEntity overview;

  @override
  Widget build(BuildContext context) {
    if (overview.points.isEmpty) {
      return AppEmptyState(
        title: 'Aucune séance sur la période',
        message: 'Termine une séance pour voir ton volume ici.',
        icon: AppIcons.progress,
        actionLabel: 'Lancer une séance',
        onAction: () => context.push(AppRoutes.templates),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VolumeCard(overview: overview),
        const SizedBox(height: AppSpacing.md),
        ProgressTiles(overview: overview),
      ],
    );
  }
}
