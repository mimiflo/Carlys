import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';
import 'current_exercise_card.dart';
import 'exercise_picker_sheet.dart';
import 'exercise_sets_table.dart';
import 'set_entry_card.dart';
import 'set_entry_fields.dart';

/// Panneau défilant de l'exercice en cours : la carte de l'exercice, la
/// carte de saisie, puis le tableau de ses séries.
///
/// Le panneau ignore tout des modèles de séance : il reçoit une consigne déjà
/// formulée ([setRank], [plannedReps], [plannedWeightKg]…) et des actions
/// facultatives. Sans consigne, son rendu est **exactement** celui d'une
/// séance libre.
class ExercisePane extends StatelessWidget {
  const ExercisePane({
    required this.exercise,
    required this.exerciseSets,
    required this.previous,
    required this.onValidate,
    required this.onDelete,
    this.plannedDurationSeconds,
    this.setRank,
    this.setsInExercise,
    this.planItemId,
    this.plannedReps,
    this.plannedWeightKg,
    this.upcomingSets = 0,
    this.onSkipSet,
    this.onSkipExercise,
    super.key,
  });

  final PickedExercise exercise;

  /// Séries de l'exercice en cours, dans l'ordre de saisie.
  final List<WorkoutSetEntry> exerciseSets;

  /// Dernière performance connue sur cet exercice.
  final WorkoutSetEntry? previous;

  /// « Série 2 sur 4 » selon le programme ; `null` hors modèle.
  final int? setRank;
  final int? setsInExercise;

  /// Série prévue que la prochaine validation honorerait : sert de clé de
  /// réinitialisation de la saisie, pour que chaque série reparte de sa cible.
  final String? planItemId;

  final int? plannedReps;
  final int? plannedDurationSeconds;
  final double? plannedWeightKg;

  /// Séries prévues restant après celle en cours de saisie — dessinées en
  /// lignes « à venir » pour rendre l'avancement dans le programme visible.
  final int upcomingSets;

  /// Passer la série prévue / tout le reste de l'exercice. `null` hors modèle.
  final VoidCallback? onSkipSet;
  final VoidCallback? onSkipExercise;

  final void Function(SetEntryValues values) onValidate;
  final Future<void> Function(String setId) onDelete;

  @override
  Widget build(BuildContext context) {
    final timeMode =
        exercise.measure == SetMeasure.timeAndDistance ||
        plannedDurationSeconds != null ||
        exerciseSets.any((set) => set.durationSeconds != null);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CurrentExerciseCard(
            name: exercise.name,
            doneSets: exerciseSets.length,
            upcomingSets: upcomingSets,
            setRank: setRank,
            setsInExercise: setsInExercise,
          ),
          const SizedBox(height: AppSpacing.gapTile),
          SetEntryCard(
            // Changer d'exercice — ou passer à la série prévue suivante —
            // réinitialise la saisie sur la nouvelle amorce.
            key: ValueKey('${exercise.name}#${planItemId ?? ''}'),
            setNumber: setRank ?? exerciseSets.length + 1,
            previous: previous,
            plannedReps: plannedReps,
            plannedWeightKg: plannedWeightKg,
            plannedDurationSeconds: plannedDurationSeconds,
            measure: exercise.measure,
            onValidate: onValidate,
            onSkipSet: onSkipSet,
            onSkipExercise: onSkipExercise,
          ),
          const SizedBox(height: AppSpacing.gapSection),
          ExerciseSetsTable(
            sets: exerciseSets,
            upcomingSets: upcomingSets,
            timeMode: timeMode,
            plannedWeightKg: plannedWeightKg,
            plannedReps: plannedReps,
            setRank: setRank,
            setsInExercise: setsInExercise,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}
