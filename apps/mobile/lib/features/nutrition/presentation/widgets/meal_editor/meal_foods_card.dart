import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/nutrition.dart';
import '../../../domain/meal_bounds.dart';
import 'food_source_mention.dart';
import 'meal_food_row.dart';

/// La carte ALIMENTS COMPOSANT LE REPAS : les lignes, le bouton pointillé
/// qui en ajoute une, et la mention de la base d'où viennent leurs valeurs.
///
/// Sans aliment, la carte ne reste pas vide : elle dit ce qu'une
/// composition apporte (les calories et les macros se calculent seules).
class MealFoodsCard extends StatelessWidget {
  const MealFoodsCard({
    required this.lines,
    required this.attribution,
    required this.onAdd,
    required this.onQuantity,
    required this.onRemove,
    super.key,
  });

  final List<MealLine> lines;

  /// La mention de la base (licence Etalab : obligatoire près des valeurs
  /// qui en viennent), `null` tant qu'aucune réponse ne l'a donnée.
  final FoodAttribution? attribution;

  /// `null` pendant un envoi : la composition ne bouge plus.
  final VoidCallback? onAdd;
  final ValueChanged<MealLine> onQuantity;
  final ValueChanged<MealLine> onRemove;

  @override
  Widget build(BuildContext context) {
    final full = lines.length >= MealBounds.componentsMax;
    return AppTitledCard(
      icon: AppIcons.mealFoods,
      title: 'Aliments composant le repas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lines.isEmpty)
            Text(
              'Compose ton repas à partir d’aliments : les calories et les '
              'macros se calculeront toutes seules.',
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            )
          else
            for (final (index, line) in lines.indexed) ...[
              if (index > 0)
                const Divider(
                  height: AppSpacing.xs,
                  color: AppColors.rowDivider,
                ),
              MealFoodRow(
                key: ValueKey(line.id),
                line: line,
                onQuantity: () => onQuantity(line),
                onRemove: () => onRemove(line),
              ),
            ],
          const SizedBox(height: AppSpacing.sm),
          AppDashedButton(
            label: 'Ajouter un aliment',
            icon: AppIcons.addFood,
            onPressed: full ? null : onAdd,
          ),
          if (lines.isNotEmpty && attribution != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FoodSourceMention(
              attribution: attribution!,
              versions: [
                for (final line in lines)
                  if (line.sourceVersion != null) line.sourceVersion!,
              ],
            ),
          ],
        ],
      ),
    );
  }
}
