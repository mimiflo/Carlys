import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/nutrition.dart';
import 'food_identity_row.dart';
import 'meal_icons.dart';

/// Un aliment trouvé dans la base : la vignette de sa famille (la table n'a
/// pas de photos), son nom court et son nom officiel, et ses calories POUR
/// 100 g — l'unité de la table, pas celle de l'assiette.
///
/// Toute la rangée répond au doigt, et le lecteur d'écran la lit d'un
/// seul tenant : « Poulet, filet, sans peau, cuit : 150 kcal pour 100 g ».
class FoodResultRow extends StatelessWidget {
  const FoodResultRow({required this.food, required this.onTap, super.key});

  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kcal = '${food.per100g.kcal.round()} kcal';
    final energy = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kcal,
          style: AppTypography.metricS.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        Text(
          'pour 100 g',
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextTertiary,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: '${food.name} : $kcal pour 100 g',
      hint: 'Ajouter cet aliment',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: FoodIdentityRow(
              icon: food.family.icon,
              shortName: food.shortName,
              name: food.name,
              trailing: energy,
            ),
          ),
        ),
      ),
    );
  }
}
