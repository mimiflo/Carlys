import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Une grandeur de la carte de série, dans son cadre : son nom (« Charge »),
/// la valeur en grand, l'unité, puis − et +. Une colonne par grandeur.
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorderStrong),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          // Une charge se lit EN ENTIER pendant la saisie : « 102,5 » se
          // resserre plutôt que de finir en « 10… ».
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.metricXL.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
          Text(
            unit,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Deux disques de 48 points ne tiennent pas côte à côte sur un
          // écran de 320 : ils passent alors l'un sous l'autre.
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _StepButton(
                icon: AppIcons.minus,
                tooltip: 'Diminuer : $label',
                onPressed: onDecrement,
              ),
              _StepButton(
                icon: AppIcons.add,
                tooltip: 'Augmenter : $label',
                onPressed: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Un disque de 48 points : la cible tactile EST le disque, à la salle,
/// d'un pouce pressé entre deux séries.
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
        width: AppSpacing.touchTarget,
        height: AppSpacing.touchTarget,
      ),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.darkSurfaceAlt,
        disabledBackgroundColor: AppColors.darkSurfaceAlt,
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 24,
        // Le « + » en violet, le « − » en clair : on charge plus souvent
        // qu'on ne retire, et le geste courant se repère d'un coup d'œil.
        color: onPressed == null
            ? AppColors.darkIconInactive
            : icon == AppIcons.add
            ? AppColors.primaryLight
            : AppColors.darkTextPrimary,
      ),
    );
  }
}
