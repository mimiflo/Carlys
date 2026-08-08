import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../nutrition/domain/entities/nutrition.dart';
import '../../../progress/domain/entities/progress.dart';

/// Grille de 3 tuiles : objectif calorique, protéines, volume de la semaine —
/// issues du rapport métabolique et de la progression.
///
/// Une jauge n'apparaît que si un ratio réel existe : le domaine ne connaît
/// ni les repas consommés ni un objectif de volume.
class HomeStatTiles extends StatelessWidget {
  const HomeStatTiles({required this.report, required this.week, super.key});

  final MetabolismReport? report;
  final ProgressOverviewEntity? week;

  @override
  Widget build(BuildContext context) {
    final metabolism = report?.metabolism;
    final overview = week;
    final volume =
        overview == null ? null : formatVolume(overview.totalVolumeKg);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppStatTile(
              label: 'Kcal',
              value: metabolism == null
                  ? '—'
                  : formatThousands(metabolism.targetKcal),
              // Part du métabolisme de base dans l'objectif : ratio réel,
              // faute de suivi des repas.
              progress: metabolism == null
                  ? null
                  : (metabolism.bmrKcal / metabolism.targetKcal)
                      .clamp(0.0, 1.0),
              gaugeColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.gapTile),
          Expanded(
            child: AppStatTile(
              label: 'Protéines',
              value: metabolism == null
                  ? '—'
                  : formatThousands(metabolism.proteinG),
              unit: metabolism == null ? null : 'g',
              // Part des protéines dans l'objectif calorique (4 kcal/g).
              progress: metabolism == null
                  ? null
                  : (metabolism.proteinG *
                          _kcalPerProteinGram /
                          metabolism.targetKcal)
                      .clamp(0.0, 1.0),
              gaugeColor: AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.gapTile),
          Expanded(
            child: AppStatTile(
              label: 'Volume',
              value: volume?.value ?? '—',
              unit: volume?.unit,
              gaugeColor: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }

  /// Équivalence énergétique des protéines (Atwater).
  static const double _kcalPerProteinGram = 4;
}
