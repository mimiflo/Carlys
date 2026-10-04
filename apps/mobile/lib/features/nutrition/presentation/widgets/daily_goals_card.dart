import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';
import '../../domain/services/day_intake.dart';
import 'kcal_ring.dart';

/// « Tes objectifs du jour » : l'anneau des calories, et une barre par
/// valeur — ce qui a été mangé (le journal) sur ce que vise le profil (le
/// serveur). Rien d'estimé ici : deux chiffres réels, et leur rapport.
class DailyGoalsCard extends StatelessWidget {
  const DailyGoalsCard({required this.target, required this.intake, super.key});

  final MetabolismResult target;
  final DayIntake intake;

  static const double _ringDiameter = 120;

  /// En dessous, l'anneau passe au-dessus des barres au lieu d'à côté.
  static const double _sideBySideWidth = 280;

  @override
  Widget build(BuildContext context) {
    final bars = _GoalBars(target: target, intake: intake);
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // L'anneau grandit avec le texte qu'il porte, sans dépasser la carte.
          final ring = KcalRing(
            eaten: intake.kcal,
            target: target.targetKcal,
            diameter: MediaQuery.textScalerOf(
              context,
            ).scale(_ringDiameter).clamp(0, constraints.maxWidth),
          );
          final side =
              constraints.maxWidth >=
              MediaQuery.textScalerOf(context).scale(_sideBySideWidth);
          if (!side) {
            return Column(
              children: [
                ring,
                const SizedBox(height: AppSpacing.md),
                bars,
              ],
            );
          }
          return Row(
            children: [
              ring,
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: bars),
            ],
          );
        },
      ),
    );
  }
}

class _GoalBars extends StatelessWidget {
  const _GoalBars({required this.target, required this.intake});

  final MetabolismResult target;
  final DayIntake intake;

  @override
  Widget build(BuildContext context) {
    final percent = target.targetKcal == 0
        ? 0
        : (intake.kcal * 100 / target.targetKcal).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tes objectifs du jour',
                style: AppTypography.subheading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
            Text(
              '$percent %',
              style: AppTypography.subheading.copyWith(
                color: AppColors.primaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _GoalBar(
          icon: AppIcons.nutrientEnergy,
          tint: AppColors.nutritionEnergy,
          label: 'Calories',
          eaten: intake.kcal,
          target: target.targetKcal,
          unit: 'kcal',
        ),
        _GoalBar(
          icon: AppIcons.protein,
          tint: AppColors.nutritionProtein,
          label: 'Protéines',
          eaten: intake.proteinG,
          target: target.proteinG,
          unit: 'g',
        ),
        _GoalBar(
          icon: AppIcons.nutrientCarbs,
          tint: AppColors.nutritionCarbs,
          label: 'Glucides',
          eaten: intake.carbsG,
          target: target.carbsG,
          unit: 'g',
        ),
        _GoalBar(
          icon: AppIcons.nutrientFat,
          tint: AppColors.nutritionFat,
          label: 'Lipides',
          eaten: intake.fatG,
          target: target.fatG,
          unit: 'g',
        ),
      ],
    );
  }
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({
    required this.icon,
    required this.tint,
    required this.label,
    required this.eaten,
    required this.target,
    required this.unit,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final int eaten;
  final int target;
  final String unit;

  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final amounts =
        '${formatThousands(eaten)} / ${formatThousands(target)} $unit';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: MergeSemantics(
        child: Row(
          children: [
            Icon(icon, color: tint, size: _iconSize),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Côte à côte quand ils tiennent, l'un sous l'autre sinon.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: AppSpacing.xs,
                    children: [
                      Text(
                        label,
                        style: AppTypography.label.copyWith(
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                      Text(
                        amounts,
                        style: AppTypography.label.copyWith(
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  AppGauge(
                    progress: target == 0 ? 0 : eaten / target,
                    color: tint,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
