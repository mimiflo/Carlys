import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/nutrition.dart';
import '../../utils/meal_editor_state.dart';
import 'food_identity_row.dart';
import 'meal_icons.dart';

/// Une ligne de la composition : la vignette de sa famille, son nom court et
/// son nom officiel, sa quantité, et la croix qui la retire.
///
/// Toucher la quantité la corrige ; la ligne garde alors son identifiant,
/// donc le serveur garde son instantané de la table.
class MealFoodRow extends StatelessWidget {
  const MealFoodRow({
    required this.line,
    required this.onQuantity,
    required this.onRemove,
    super.key,
  });

  final MealLine line;
  final VoidCallback onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final grams = '${formatQuantityInput(line.quantityG)} g';
    final gestures = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuantityButton(
          label: grams,
          semanticLabel: 'Quantité de ${line.shortName} : $grams. Modifier',
          onTap: onQuantity,
        ),
        IconButton(
          onPressed: onRemove,
          tooltip: 'Retirer ${line.shortName}',
          icon: const Icon(AppIcons.close, color: AppColors.darkTextTertiary),
        ),
      ],
    );
    // Une ligne, un nœud : ses deux noms s'y lisent ensemble, suivis de ses
    // deux gestes, au lieu de se fondre dans un bloc de toute la carte.
    return Semantics(
      container: true,
      child: FoodIdentityRow(
        icon: line.family.icon,
        shortName: line.shortName,
        name: line.name,
        trailing: gestures,
      ),
    );
  }
}

/// La quantité d'une ligne, qui s'ouvre au toucher pour être corrigée : un
/// nombre en chiffres tabulaires, dans une cible tactile entière.
class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSpacing.touchTarget,
            minHeight: AppSpacing.touchTarget,
          ),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                label,
                style: AppTypography.metricS.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
