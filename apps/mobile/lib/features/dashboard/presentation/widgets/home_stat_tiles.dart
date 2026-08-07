import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../nutrition/domain/entities/nutrition.dart';
import '../../../progress/domain/entities/progress.dart';

/// Grille de 3 tuiles de l'accueil : objectif kcal, protéines, volume de
/// la semaine — issues du rapport métabolique et de la progression.
class HomeStatTiles extends StatelessWidget {
  const HomeStatTiles({required this.report, required this.week, super.key});

  final MetabolismReport? report;
  final ProgressOverviewEntity? week;

  @override
  Widget build(BuildContext context) {
    final metabolism = report?.metabolism;
    final volume = week?.totalVolumeKg ?? 0;

    return Row(
      children: [
        Expanded(
          child: AppStatTile(
            label: 'Kcal',
            value: metabolism == null ? '—' : '${metabolism.targetKcal}',
            // Ratio dépense de base / objectif : lecture réelle, pas de
            // suivi de repas pour l'instant.
            progress: metabolism == null
                ? null
                : (metabolism.bmrKcal / metabolism.targetKcal).clamp(0.0, 1.0),
            gaugeColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.gapTile),
        Expanded(
          child: AppStatTile(
            label: 'Protéines',
            value: metabolism == null ? '—' : '${metabolism.proteinG}',
            unit: metabolism == null ? null : 'g',
            gaugeColor: AppColors.accent,
          ),
        ),
        const SizedBox(width: AppSpacing.gapTile),
        Expanded(
          child: AppStatTile(
            label: 'Volume',
            value: week == null ? '—' : _volume(volume),
            unit: week == null ? null : ' kg',
            gaugeColor: AppColors.primaryLight,
          ),
        ),
      ],
    );
  }

  static String _volume(double kg) => kg >= 10000
      ? '${(kg / 1000).toStringAsFixed(1).replaceAll('.', ',')} t'
      : '${kg.round()}';
}
