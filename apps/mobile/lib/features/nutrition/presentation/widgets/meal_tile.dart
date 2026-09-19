import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/meal_entry.dart';
import 'meal_moment_rows.dart';

/// Une ligne du journal : l'heure, le nom, ce qu'on en sait, et les deux
/// gestes qui s'y appliquent.
///
/// L'heure est en tête parce qu'elle EXPLIQUE l'ordre de la liste, triée par
/// instant de consommation : sans elle, deux « Poulet riz » dans la journée
/// se ressemblaient au point qu'on ne savait plus lequel corriger.
class MealTile extends StatelessWidget {
  const MealTile({
    required this.meal,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final MealEntry meal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Une macro inconnue ne s'écrit PAS « 0 g » : elle ne s'écrit pas du
    // tout. Le serveur distingue l'absence du zéro, l'écran aussi.
    final details = [
      '${formatThousands(meal.kcal)} kcal',
      if (meal.spelledQuantity != null) meal.spelledQuantity!,
      if (meal.proteinG != null) '${meal.proteinG} g de protéines',
      if (meal.carbsG != null) '${meal.carbsG} g de glucides',
      if (meal.fatG != null) '${meal.fatG} g de lipides',
    ];

    return AppCard(
      onTap: onEdit,
      semanticLabel: 'Corriger ${meal.name}',
      child: Row(
        children: [
          Text(
            MealMomentRows.spellTime(meal.eatenAt.toLocal()),
            style: AppTypography.labelMono.copyWith(
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                Text(
                  details.join(' · '),
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Retirer ce repas',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.darkTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
