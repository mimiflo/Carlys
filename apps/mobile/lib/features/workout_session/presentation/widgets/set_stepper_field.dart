import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Colonne de saisie de la carte de série : label mono, champ à pas
/// (− valeur +) et unité. Une colonne par grandeur (charge, répétitions).
class SetStepperField extends StatelessWidget {
  const SetStepperField({
    required this.label,
    required this.value,
    required this.unit,
    required this.onIncrement,
    this.onDecrement,
    super.key,
  });

  final String label;

  /// Valeur déjà formatée (formatting.dart) — jamais un nombre brut.
  final String value;
  final String unit;
  final VoidCallback onIncrement;

  /// `null` quand la borne basse est atteinte.
  final VoidCallback? onDecrement;

  /// Géométrie de la maquette : icônes 20, boîte tactile 32, champ ~48.
  static const double _iconSize = 20;
  static const double _tapSize = 32;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelMono.copyWith(
            fontSize: 9,
            letterSpacing: 1.08,
            color: AppColors.darkTextTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.darkBackground,
            borderRadius: AppRadius.statTileAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StepButton(
                  icon: AppIcons.minus,
                  tooltip: 'Diminuer : $label',
                  onPressed: onDecrement,
                ),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.metricL.copyWith(
                      fontSize: 24,
                      letterSpacing: -0.72,
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                ),
                _StepButton(
                  icon: AppIcons.add,
                  tooltip: 'Augmenter : $label',
                  onPressed: onIncrement,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          unit.toUpperCase(),
          style: AppTypography.labelMono.copyWith(
            fontWeight: FontWeight.w400,
            color: AppColors.darkTextTertiary,
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: SetStepperField._tapSize,
        height: SetStepperField._tapSize,
      ),
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: SetStepperField._iconSize,
        color: onPressed == null
            ? AppColors.darkIconInactive
            : AppColors.primaryLight,
      ),
    );
  }
}
