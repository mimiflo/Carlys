import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Section « Exécution » (maquette 2e) : étapes numérotées en accent, texte
/// secondaire aéré. Le contenu vient d'`ExerciseDetail.instructions`.
class ExerciseStepsSection extends StatelessWidget {
  const ExerciseStepsSection({required this.steps, super.key});

  final List<String> steps;

  static const double _badgeSize = 22;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: 'Exécution'),
        const SizedBox(height: AppSpacing.sm),
        for (final (index, step) in steps.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _badgeSize,
                height: _badgeSize,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.accentBadgeBg,
                  borderRadius: AppRadius.smAll,
                ),
                child: Text(
                  '${index + 1}',
                  style: AppTypography.metricS.copyWith(
                    fontSize: 11,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  step,
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
