import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// « Exécution » (maquette d'octobre 2026) : les étapes numérotées en
/// accent, dans une carte, séparées d'un trait. Le contenu vient
/// d'`ExerciseDetail.instructions`.
class ExerciseStepsSection extends StatelessWidget {
  const ExerciseStepsSection({required this.steps, super.key});

  final List<String> steps;

  static const double _badgeSize = 28;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Exécution',
              style: AppTypography.subheading.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final (index, step) in steps.indexed) ...[
            if (index > 0)
              const Divider(height: 1, color: AppColors.rowDivider),
            MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      width: _badgeSize,
                      height: _badgeSize,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.accentBadgeBg,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        semanticsLabel: 'Étape ${index + 1}',
                        style: AppTypography.metricS.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        step,
                        style: AppTypography.body.copyWith(
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
