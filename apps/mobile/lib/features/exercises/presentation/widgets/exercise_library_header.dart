import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/exercise_library_controller.dart';
import 'exercise_difficulty_sheet.dart';

/// En-tête de la bibliothèque (maquette 2d) : titre à gauche, accès aux
/// filtres avancés à droite. L'icône passe en accent quand un filtre de
/// difficulté est actif — l'état reste lisible sans ouvrir la feuille.
class ExerciseLibraryHeader extends ConsumerWidget {
  const ExerciseLibraryHeader({super.key});

  static const double _titleSize = 27;
  static const double _iconSize = 23;
  static const double _tapTarget = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final difficulty = ref
        .watch(exerciseLibraryControllerProvider)
        .valueOrNull
        ?.filters
        .difficulty;

    return Row(
      children: [
        // Retour vers le hub Training — la bibliothèque est une sous-page.
        const AppBackButton(),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            'Exercices',
            style: AppTypography.display.copyWith(
              fontSize: _titleSize,
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: difficulty == null
              ? 'Filtrer par difficulté'
              : 'Filtre de difficulté : ${difficulty.label}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showExerciseDifficultySheet(context),
            child: SizedBox(
              width: _tapTarget,
              height: _tapTarget,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  AppIcons.filter,
                  size: _iconSize,
                  color: difficulty == null
                      ? AppColors.darkTextSecondary
                      : AppColors.accent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
