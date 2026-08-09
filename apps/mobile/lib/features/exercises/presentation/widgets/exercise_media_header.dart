import 'package:flutter/material.dart';

import '../../../../core/media/remote_image.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';

/// En-tête média de la fiche (maquette 2e).
///
/// La photo vient du stockage objet, déposée depuis l'administration. Tant
/// qu'aucune n'est rattachée — le cas de la plupart des mouvements — le bloc
/// garde son dégradé sombre et sa grande icône atténuée. Dans les deux cas, le
/// voile du bas et le titre restent identiques : la fiche ne change pas de
/// forme selon qu'elle est illustrée ou non.
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
          if (exercise.imageUrl == null)
            const _MediaPlaceholder()
          else
            RemoteImage(
              url: exercise.imageUrl!,
              placeholder: const _MediaPlaceholder(),
              semanticLabel: 'Photo du mouvement',
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

/// Repli de l'en-tête : dégradé sombre et icône très atténuée.
class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.neutral900, AppColors.neutral950],
        ),
      ),
      child: ExcludeSemantics(
        child: Center(
          child: Icon(
            AppIcons.workout,
            size: ExerciseMediaHeader._placeholderIconSize,
            color: AppColors.primaryLight.withValues(
              alpha: ExerciseMediaHeader._placeholderAlpha,
            ),
          ),
        ),
      ),
    );
  }
}
