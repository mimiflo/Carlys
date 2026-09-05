import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// En-tête de l'onboarding sur UNE ligne : retour, barre de progression
/// continue, compteur « 2/4 ».
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    required this.step,
    required this.stepCount,
    required this.onBack,
    super.key,
  });

  /// Index de l'étape courante (0 = première).
  final int step;
  final int stepCount;

  /// `null` à la première étape : la flèche disparaît, sa place reste
  /// réservée pour que la barre ne bouge pas d'une étape à l'autre.
  final VoidCallback? onBack;

  /// Géométrie de la maquette : flèche 22, barre de 3 de haut.
  static const double _iconSize = 22;
  static const double _barHeight = 3;

  @override
  Widget build(BuildContext context) {
    final position =
        '${formatThousands(step + 1)}/${formatThousands(stepCount)}';

    return Row(
      children: [
        SizedBox(
          width: _iconSize,
          height: _iconSize,
          child: onBack == null
              ? null
              : Semantics(
                  button: true,
                  label: 'Étape précédente',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBack,
                    child: const Icon(
                      AppIcons.back,
                      size: _iconSize,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: AppSpacing.gapRow),
        Expanded(
          child: Semantics(
            label: 'Étape ${step + 1} sur $stepCount',
            child: _ProgressBar(
              progress: (step + 1) / stepCount,
              height: _barHeight,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.gapRow),
        Text(
          position,
          style: AppTypography.labelMono.copyWith(
            color: AppColors.darkTextTertiary,
          ),
        ),
      ],
    );
  }
}

/// Barre continue : piste neutre, remplissage accent proportionnel.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.height});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.fullAll,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.gaugeTrack),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress.clamp(0, 1)),
              duration: AppMotion.resolve(context, AppMotion.normal),
              curve: AppMotion.standard,
              builder: (context, value, child) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: child,
              ),
              child: const ColoredBox(color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
