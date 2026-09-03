import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout_template.dart';

/// Repos prévu après une série, réglé au pas — compact, sur une seule ligne :
/// c'est une consigne secondaire à côté de la charge et des répétitions.
///
/// Les bornes sont celles partagées avec l'API : refuser ici, c'est éviter un
/// refus serveur des heures plus tard, en `failed`.
class PlannedRestField extends StatelessWidget {
  const PlannedRestField({
    required this.seconds,
    required this.onChanged,
    super.key,
  });

  /// `null` vaut zéro : un modèle sans repos prévu enchaîne les séries.
  final int? seconds;
  final ValueChanged<int> onChanged;

  /// Pas de saisie : le quart de minute, unité usuelle des repos.
  static const int step = 15;

  @override
  Widget build(BuildContext context) {
    final value = seconds ?? 0;

    return Semantics(
      label: 'Repos prévu : ${formatThousands(value)} secondes',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.darkBackground,
          borderRadius: AppRadius.buttonAll,
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'REPOS',
                style: AppTypography.labelMono
                    .copyWith(color: AppColors.darkTextTertiary),
              ),
            ),
            _StepButton(
              icon: AppIcons.minus,
              tooltip: 'Diminuer le repos',
              onPressed: value >= step ? () => onChanged(value - step) : null,
            ),
            Text(
              '${formatThousands(value)} s',
              style: AppTypography.metricS
                  .copyWith(color: AppColors.darkTextPrimary),
            ),
            _StepButton(
              icon: AppIcons.add,
              tooltip: 'Augmenter le repos',
              onPressed: value + step <= WorkoutTemplateLimits.restSecondsMax
                  ? () => onChanged(value + step)
                  : null,
            ),
          ],
        ),
      ),
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

  /// Géométrie : icône 18, boîte VISUELLE 36. La boîte n'est pas la cible :
  /// l'`IconButton` élargit sa zone tactile à [AppSpacing.touchTarget]
  /// (`MaterialTapTargetSize.padded`), sans rien changer au rendu.
  static const double _iconSize = 18;
  static const double _boxSize = 36;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: _boxSize,
        height: _boxSize,
      ),
      style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.padded),
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: _iconSize,
        color: onPressed == null
            ? AppColors.darkIconInactive
            : AppColors.primaryLight,
      ),
    );
  }
}
