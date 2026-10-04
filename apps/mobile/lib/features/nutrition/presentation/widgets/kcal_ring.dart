import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// L'anneau des calories du jour : mangées, sur l'objectif, et ce qui reste
/// (ou ce qui le dépasse — l'anneau, lui, reste plein).
class KcalRing extends StatelessWidget {
  const KcalRing({
    super.key,
    required this.eaten,
    required this.target,
    required this.diameter,
  });

  final int eaten;
  final int target;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final left = target - eaten;
    final rest = left >= 0
        ? '${formatThousands(left)} kcal\nrestantes'
        : '${formatThousands(-left)} kcal\nau-delà';
    return Semantics(
      label:
          '${formatThousands(eaten)} kcal sur '
          '${formatThousands(target)}, ${rest.replaceAll('\n', ' ')}',
      child: ExcludeSemantics(
        child: AppProgressRing(
          progress: target == 0 ? 0 : eaten / target,
          diameter: diameter,
          // Le texte tient DANS l'anneau à toute taille : réduit, jamais
          // coupé ni débordant (le lecteur d'écran lit l'étiquette entière).
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatThousands(eaten),
                    style: AppTypography.metricL.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  Text(
                    '/ ${formatThousands(target)} kcal',
                    style: AppTypography.label.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    rest,
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
