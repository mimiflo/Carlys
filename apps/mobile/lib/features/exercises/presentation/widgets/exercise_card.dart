import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';

/// Carte d'un exercice dans la bibliothèque.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({required this.exercise, required this.onTap, super.key});

  final ExerciseSummary exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      semanticLabel: 'Exercice ${exercise.name}',
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(AppIcons.workout, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  spacing: AppSpacing.xxs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    if (exercise.primaryMuscleGroup != null)
                      AppBadge(
                        label: exercise.primaryMuscleGroup!.name,
                        variant: AppBadgeVariant.primary,
                      ),
                    AppBadge(label: exercise.difficulty.label),
                    if (exercise.isPremium)
                      const AppBadge(
                        label: 'Premium',
                        variant: AppBadgeVariant.accent,
                        icon: AppIcons.premium,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
