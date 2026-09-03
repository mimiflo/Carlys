import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../progression/presentation/widgets/progression_entry_card.dart';
import '../../../progression/presentation/widgets/reward_showcase.dart';
import '../../domain/entities/progress.dart';
import '../controllers/progress_controllers.dart';
import '../widgets/body_weight_section.dart';
import '../widgets/progress_first_steps.dart';
import '../widgets/progress_header.dart';
import '../widgets/progress_tiles.dart';
import '../widgets/records_section.dart';
import '../widgets/volume_card.dart';

/// Progression (maquette 2c) : volume de la période et sa tendance, tuiles
/// de synthèse, records personnels puis suivi du poids corporel.
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
      backgroundColor: AppColors.darkBackground,
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
              // Le profil de progression tient sur les faits LOCAUX : il
              // a quelque chose à dire même le premier jour.
              const ProgressionEntryCard(),
            ] else ...[
              overview.when(
                loading: () => const AppLoadingIndicator(
                  label: 'Chargement des statistiques',
                ),
                error: (_, __) => AppErrorState(
                  title: 'Statistiques indisponibles',
                  message: AppErrorState.retryConnectionMessage,
                  onRetry: () => ref.invalidate(progressOverviewProvider),
                ),
                data: (data) => _OverviewBlock(overview: data),
              ),
              const SizedBox(height: AppSpacing.md),
              // Le profil de progression tient sur les faits LOCAUX : il
              // s'affiche donc même quand les statistiques du serveur, juste
              // au-dessus, sont en erreur ou hors ligne.
              const ProgressionEntryCard(),
              const SizedBox(height: AppSpacing.gapSection),
              // La vitrine, sans « ce qui vient » : l'écran Progrès raconte
              // la période, le profil raconte l'histoire entière et la
              // direction.
              const RewardShowcase(showUpcoming: false),
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
