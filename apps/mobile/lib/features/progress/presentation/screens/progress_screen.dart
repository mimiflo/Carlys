import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../progression/presentation/widgets/progression_entry_card.dart';
import '../../../progression/presentation/widgets/reward_showcase.dart';
import '../../domain/entities/progress.dart';
import '../controllers/progress_controllers.dart';
import '../widgets/body_weight_section.dart';
import '../widgets/progress_header.dart';
import '../widgets/progress_tiles.dart';
import '../widgets/records_section.dart';
import '../widgets/volume_card.dart';

/// Progression (maquette 2c) : volume de la période et sa tendance, tuiles
/// de synthèse, records personnels puis suivi du poids corporel.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(progressOverviewProvider);
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
            overview.when(
              loading: () => const AppLoadingIndicator(
                label: 'Chargement des statistiques',
              ),
              error: (_, __) => AppErrorState(
                title: 'Statistiques indisponibles',
                message: 'Vérifiez votre connexion puis réessayez.',
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
            // La vitrine, sans « ce qui vient » : l'écran Progrès raconte la
            // période, le profil raconte l'histoire entière et la direction.
            const RewardShowcase(showUpcoming: false),
            const SizedBox(height: AppSpacing.gapSection),
            const RecordsSection(),
            const SizedBox(height: AppSpacing.gapSection),
            const BodyWeightSection(),
          ],
        ),
      ),
    );
  }
}

/// Carte de volume + tuiles : la carte cède la place à un état vide quand
/// aucune séance n'a été enregistrée sur la période.
class _OverviewBlock extends StatelessWidget {
  const _OverviewBlock({required this.overview});

  final ProgressOverviewEntity overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overview.points.isEmpty)
          const AppEmptyState(
            title: 'Aucune séance sur la période',
            message: 'Terminez une séance pour voir votre volume ici.',
            icon: AppIcons.progress,
          )
        else
          VolumeCard(overview: overview),
        const SizedBox(height: AppSpacing.md),
        ProgressTiles(overview: overview),
      ],
    );
  }
}
