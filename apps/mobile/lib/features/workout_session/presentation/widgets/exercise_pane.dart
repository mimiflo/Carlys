import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';
import 'exercise_picker_sheet.dart';
import 'exercise_set_row.dart';
import 'set_entry_card.dart';

/// Panneau défilant de l'exercice en cours : sur-titre, nom, carte de saisie
/// et séries déjà enregistrées suivies de la série à saisir.
class ExercisePane extends StatelessWidget {
  const ExercisePane({
    required this.exercise,
    required this.sessionSetsCount,
    required this.exerciseSets,
    required this.previous,
    required this.onValidate,
    required this.onDelete,
    super.key,
  });

  final PickedExercise exercise;

  /// Nombre de séries déjà enregistrées dans la séance (tous exercices).
  final int sessionSetsCount;

  /// Séries de l'exercice en cours, dans l'ordre de saisie.
  final List<WorkoutSetEntry> exerciseSets;

  /// Dernière performance connue sur cet exercice.
  final WorkoutSetEntry? previous;

  final void Function(double weightKg, int reps) onValidate;
  final Future<void> Function(String setId) onDelete;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.gapSection,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionLabel(
            'Série ${formatThousands(sessionSetsCount + 1)} de la séance',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            exercise.name,
            style: AppTypography.display.copyWith(
              fontSize: 28,
              height: 1.08,
              letterSpacing: -0.84,
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          SetEntryCard(
            // Changer d'exercice réinitialise la saisie.
            key: ValueKey(exercise.name),
            setNumber: exerciseSets.length + 1,
            previous: previous,
            onValidate: onValidate,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < exerciseSets.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.xs),
            ExerciseSetRow(
              position: index + 1,
              set: exerciseSets[index],
              onDelete: () => onDelete(exerciseSets[index].id),
            ),
          ],
          if (exerciseSets.isNotEmpty) const SizedBox(height: AppSpacing.xs),
          ExerciseSetRow(position: exerciseSets.length + 1),
        ],
      ),
    );
  }
}
