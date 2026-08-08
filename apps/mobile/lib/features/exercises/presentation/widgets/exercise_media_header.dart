import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';

/// En-tête média de la fiche (maquette 2e).
///
/// Aucun média n'existe encore côté domaine : le bloc reste un placeholder
/// assumé — dégradé sombre, grande icône très atténuée, voile vers le bas —
/// surmonté du sur-titre « GROUPE · TYPE » et du nom du mouvement.
class ExerciseMediaHeader extends StatelessWidget {
  const ExerciseMediaHeader({required this.exercise, super.key});

  final ExerciseDetail exercise;

  static const double height = 300;
  static const double _placeholderIconSize = 96;
  static const double _placeholderAlpha = 0.22;

  @override
  Widget build(BuildContext context) {
    final overline = [
      if (exercise.primaryMuscleGroup != null)
        exercise.primaryMuscleGroup!.name,
      exercise.kind.label,
    ].join(' · ');

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.neutral900, AppColors.neutral950],
              ),
            ),
          ),
          ExcludeSemantics(
            child: Center(
              child: Icon(
                AppIcons.workout,
                size: _placeholderIconSize,
                color:
                    AppColors.primaryLight.withValues(alpha: _placeholderAlpha),
              ),
            ),
          ),
          // Voile : le bas de l'image se fond dans le fond de l'écran.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.3, 0.82, 1],
                colors: [
                  AppColors.darkBackground.withValues(alpha: 0.6),
                  AppColors.darkBackground.withValues(alpha: 0),
                  AppColors.darkBackground.withValues(alpha: 0.85),
                  AppColors.darkBackground,
                ],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.gutter,
            right: AppSpacing.gutter,
            bottom: AppSpacing.xxs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSectionLabel(overline),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  exercise.name,
                  style: AppTypography.display
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
