import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';

/// Ligne du catalogue (maquette 2d) : vignette 58 en dégradé, nom, sous-ligne
/// mono « GROUPE · MATÉRIEL », tirets de difficulté et chevron.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({required this.exercise, required this.onTap, super.key});

  final ExerciseSummary exercise;
  final VoidCallback onTap;

  static const double _thumbSize = 58;
  static const double _thumbIconSize = 24;
  static const double _chevronSize = 20;
  static const double _fillStart = 0.35;
  static const double _fillEnd = 0.08;
  static const double _thumbBorderAlpha = 0.22;

  /// Nombre de tirets allumés pour un niveau de difficulté.
  static int levelOf(ExerciseDifficulty difficulty) => switch (difficulty) {
        ExerciseDifficulty.beginner => 1,
        ExerciseDifficulty.intermediate => 2,
        ExerciseDifficulty.advanced => 3,
      };

  @override
  Widget build(BuildContext context) {
    // Le orange signale les mouvements Premium (décision serveur) ; tous les
    // autres portent le violet de marque.
    final tint = exercise.isPremium ? AppColors.accent : AppColors.primary;
    final iconTint =
        exercise.isPremium ? AppColors.accent : AppColors.primaryLight;
    final subtitle = [
      if (exercise.primaryMuscleGroup != null)
        exercise.primaryMuscleGroup!.name,
      if (exercise.equipment.isNotEmpty) exercise.equipment.first.name,
    ].join(' · ');

    return Semantics(
      button: true,
      label: 'Exercice ${exercise.name}'
          '${subtitle.isEmpty ? '' : ', $subtitle'}'
          '${exercise.isPremium ? ', Premium' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.listRowAll,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: AppRadius.listRowAll,
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.darkBorder),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: _thumbSize,
                  height: _thumbSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tint.withValues(alpha: _fillStart),
                        tint.withValues(alpha: _fillEnd),
                      ],
                    ),
                    borderRadius: AppRadius.avatarAll,
                    border: Border.all(
                      color: iconTint.withValues(alpha: _thumbBorderAlpha),
                    ),
                  ),
                  child: Icon(
                    exercise.isPremium ? AppIcons.premium : AppIcons.workout,
                    size: _thumbIconSize,
                    color: iconTint,
                  ),
                ),
                const SizedBox(width: AppSpacing.gapRow),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.subheading
                            .copyWith(color: AppColors.darkTextPrimary),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMono.copyWith(
                            fontSize: 11,
                            color: AppColors.darkTextTertiary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxs),
                      AppDifficultyDashes(
                        level: levelOf(exercise.difficulty),
                        semanticLabel:
                            'Difficulté : ${exercise.difficulty.label}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  AppIcons.chevronRight,
                  size: _chevronSize,
                  color: AppColors.darkIconInactive,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
