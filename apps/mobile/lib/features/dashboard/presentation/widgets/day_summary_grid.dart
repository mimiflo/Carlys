import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../nutrition/domain/entities/nutrition.dart';
import '../../../progress/domain/entities/progress.dart';
import '../controllers/dashboard_controllers.dart';

/// « Résumé du jour » : grille 2×2 de faits, dans un cadre commun.
///
/// La maquette de référence y place aussi le sommeil et l'hydratation. Le
/// domaine ne les connaît pas : plutôt que d'afficher des chiffres inventés,
/// on garde la forme et on n'y met que du réel — l'entraînement du jour, les
/// deux objectifs nutritionnels calculés, et le volume de la semaine. Chaque
/// tuile précise sa portée, pour qu'un objectif ne se lise jamais comme un
/// consommé.
class DaySummaryGrid extends StatelessWidget {
  const DaySummaryGrid({
    required this.training,
    required this.report,
    required this.week,
    super.key,
  });

  final TodayTraining training;
  final MetabolismReport? report;
  final ProgressOverviewEntity? week;

  @override
  Widget build(BuildContext context) {
    final metabolism = report?.metabolism;
    final volume = week == null ? null : formatVolume(week!.totalVolumeKg);

    final tiles = <Widget>[
      AppSummaryTile(
        icon: AppIcons.workout,
        iconColor: AppColors.accent,
        label: 'Entraînement',
        value: training.value,
        detail: training.detail,
      ),
      AppSummaryTile(
        icon: AppIcons.nutrition,
        iconColor: AppColors.primaryLight,
        label: 'Nutrition',
        value: metabolism == null
            ? '—'
            : '${formatThousands(metabolism.targetKcal)} kcal',
        detail: metabolism == null ? null : 'objectif du jour',
      ),
      AppSummaryTile(
        icon: AppIcons.protein,
        iconColor: AppColors.primaryLight,
        label: 'Protéines',
        value: metabolism == null ? '—' : '${metabolism.proteinG} g',
        detail: metabolism == null ? null : 'objectif du jour',
      ),
      AppSummaryTile(
        icon: AppIcons.trendingUp,
        iconColor: AppColors.accent,
        label: 'Volume',
        value: volume == null ? '—' : '${volume.value} ${volume.unit}',
        detail: volume == null ? null : 'cette semaine',
      ),
    ];

    return AppLabeledCard(
      label: 'Résumé du jour',
      // Cadre commun : les quatre tuiles forment un bloc, pas quatre îlots
      // posés sur le fond. Le liseré reste discret — c'est un regroupement,
      // pas une mise en avant.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: AppSpacing.gapTile),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tiles[row * 2]),
                  const SizedBox(width: AppSpacing.gapTile),
                  Expanded(child: tiles[row * 2 + 1]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
