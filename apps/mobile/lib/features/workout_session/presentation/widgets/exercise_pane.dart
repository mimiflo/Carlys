import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';
import 'exercise_picker_sheet.dart';
import 'exercise_set_row.dart';
import 'set_entry_card.dart';

/// Panneau défilant de l'exercice en cours : sur-titre, nom, carte de saisie
/// et séries déjà enregistrées suivies de la série à saisir.
///
/// Le panneau ignore tout des modèles de séance : il reçoit une consigne déjà
/// formulée ([overline], [plannedReps], [plannedWeightKg]) et des actions
/// facultatives. Sans consigne, son rendu est **exactement** celui d'une
/// séance libre.
class ExercisePane extends StatelessWidget {
  const ExercisePane({
    required this.exercise,
    required this.sessionSetsCount,
    required this.exerciseSets,
    required this.previous,
    required this.onValidate,
    required this.onDelete,
    this.overline,
    this.planItemId,
    this.plannedReps,
    this.plannedWeightKg,
    this.upcomingSets = 0,
    this.onSkipSet,
    this.onSkipExercise,
    super.key,
  });

  final PickedExercise exercise;

  /// Nombre de séries déjà enregistrées dans la séance (tous exercices).
  final int sessionSetsCount;

  /// Séries de l'exercice en cours, dans l'ordre de saisie.
  final List<WorkoutSetEntry> exerciseSets;

  /// Dernière performance connue sur cet exercice.
  final WorkoutSetEntry? previous;

  /// Sur-titre imposé par le programme (« Série 2 sur 4 · Développé couché ») ;
  /// `null` retombe sur le rang de la série dans la séance.
  final String? overline;

  /// Série prévue que la prochaine validation honorerait : sert de clé de
  /// réinitialisation de la saisie, pour que chaque série reparte de sa cible.
  final String? planItemId;

  final int? plannedReps;
  final double? plannedWeightKg;

  /// Séries prévues restant après celle en cours de saisie — dessinées en
  /// lignes « à venir » pour rendre l'avancement dans le programme visible.
  final int upcomingSets;

  /// Passer la série prévue / tout le reste de l'exercice. `null` hors modèle.
  final VoidCallback? onSkipSet;
  final VoidCallback? onSkipExercise;

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
            overline ??
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
            // Changer d'exercice — ou passer à la série prévue suivante —
            // réinitialise la saisie sur la nouvelle amorce.
            key: ValueKey('${exercise.name}#${planItemId ?? ''}'),
            setNumber: exerciseSets.length + 1,
            previous: previous,
            plannedReps: plannedReps,
            plannedWeightKg: plannedWeightKg,
            onValidate: onValidate,
          ),
          if (onSkipSet != null || onSkipExercise != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _SkipActions(onSkipSet: onSkipSet, onSkipExercise: onSkipExercise),
          ],
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
          for (var index = 0; index < upcomingSets; index++) ...[
            const SizedBox(height: AppSpacing.xs),
            ExerciseSetRow(position: exerciseSets.length + 2 + index),
          ],
        ],
      ),
    );
  }
}

/// Sauter n'est **jamais** une erreur : ces actions restent discrètes, sans
/// aucun message de rappel à l'ordre.
class _SkipActions extends StatelessWidget {
  const _SkipActions({required this.onSkipSet, required this.onSkipExercise});

  final VoidCallback? onSkipSet;
  final VoidCallback? onSkipExercise;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onSkipSet != null)
          Expanded(
            child: TextButton(
              onPressed: onSkipSet,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.darkTextSecondary,
                textStyle: AppTypography.label,
              ),
              child: const Text('Passer cette série'),
            ),
          ),
        if (onSkipExercise != null)
          Expanded(
            child: TextButton(
              onPressed: onSkipExercise,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.darkTextSecondary,
                textStyle: AppTypography.label,
              ),
              child: const Text('Passer cet exercice'),
            ),
          ),
      ],
    );
  }
}
