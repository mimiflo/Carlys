import 'package:flutter/material.dart';

import '../../../../core/media/remote_image.dart';
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
                _Thumbnail(
                  imageUrl: exercise.imageUrl,
                  tint: tint,
                  iconTint: iconTint,
                  isPremium: exercise.isPremium,
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

/// Vignette : la photo déposée depuis l'administration si elle existe, sinon
/// la pastille de marque. Le repli n'est pas un état d'erreur — la plupart des
/// mouvements n'ont pas encore de photo, et c'est très bien ainsi.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.imageUrl,
    required this.tint,
    required this.iconTint,
    required this.isPremium,
  });

  final String? imageUrl;
  final Color tint;
  final Color iconTint;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: ExerciseCard._fillStart),
            tint.withValues(alpha: ExerciseCard._fillEnd),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          isPremium ? AppIcons.premium : AppIcons.workout,
          size: ExerciseCard._thumbIconSize,
          color: iconTint,
        ),
      ),
    );

    return Container(
      width: ExerciseCard._thumbSize,
      height: ExerciseCard._thumbSize,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppRadius.avatarAll,
        border: Border.all(
          color: iconTint.withValues(alpha: ExerciseCard._thumbBorderAlpha),
        ),
      ),
      child: imageUrl == null
          ? placeholder
          : RemoteImage(url: imageUrl!, placeholder: placeholder),
    );
  }
}
