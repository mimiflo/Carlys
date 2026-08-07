import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';

/// Ligne d'exercice de la bibliothèque (2d) : vignette 36, nom, groupe
/// musculaire en mono MAJUSCULES, chevron.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({required this.exercise, required this.onTap, super.key});

  final ExerciseSummary exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (exercise.primaryMuscleGroup != null)
        exercise.primaryMuscleGroup!.name,
      exercise.difficulty.label,
    ].join(' · ');

    return Semantics(
      label: 'Exercice ${exercise.name}',
      button: true,
      child: AppListRow(
        title: exercise.name,
        subtitle: subtitle,
        leading: AppIcons.workout,
        leadingTint:
            exercise.isPremium ? AppColors.accent : AppColors.primaryLight,
        trailing: exercise.isPremium
            ? const AppPill(
                label: 'PREMIUM',
                tone: AppPillTone.accent,
                mono: true,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
