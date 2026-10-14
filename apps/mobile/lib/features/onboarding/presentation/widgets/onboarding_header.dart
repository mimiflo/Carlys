import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// En-tête de l'onboarding (maquette d'octobre 2026) : retour, puis au
/// centre « Étape 2 sur 6 » et une barre en segments — un par étape, les
/// étapes faites et la courante en violet.
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
  /// réservée pour que le centre ne bouge pas d'une étape à l'autre.
  final VoidCallback? onBack;

  static const double _iconSize = 22;
  static const double _segmentHeight = 6;

  /// La barre ne s'étire pas sur toute la largeur : elle reste un repère.
  static const double _barMaxWidth = 240;

  @override
  Widget build(BuildContext context) {
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
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
        ),
        Expanded(
          child: Semantics(
            label: 'Étape ${step + 1} sur $stepCount',
            excludeSemantics: true,
            child: Column(
              children: [
                Text(
                  'ÉTAPE ${step + 1} SUR $stepCount',
                  style: AppTypography.labelMono.copyWith(
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _barMaxWidth),
                  child: Row(
                    children: [
                      for (var i = 0; i < stepCount; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.xxs),
                        Expanded(child: _Segment(on: i <= step)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: _iconSize),
      ],
    );
  }
}

/// Un segment : piste neutre, ou violet quand l'étape est atteinte.
class _Segment extends StatelessWidget {
  const _Segment({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.normal),
      curve: AppMotion.standard,
      height: OnboardingHeader._segmentHeight,
      decoration: BoxDecoration(
        borderRadius: AppRadius.fullAll,
        color: on ? AppColors.primary : AppColors.gaugeTrack,
      ),
    );
  }
}
