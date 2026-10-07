import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/widgets/exercise_set_row.dart';
import '../../domain/services/exercise_breakdown.dart';

/// Le tableau des séries d'un exercice, au bilan : les lignes de la séance
/// en cours ([ExerciseSetRow], unités comprises), lues seulement — ou, en
/// correction ([editing]), corrigeables d'un toucher et supprimables d'un
/// appui long.
class FinishedSetsTable extends StatelessWidget {
  const FinishedSetsTable({
    required this.exercise,
    required this.editing,
    required this.onCorrect,
    required this.onDelete,
    super.key,
  });

  final ExerciseBreakdown exercise;
  final bool editing;
  final Future<void> Function(WorkoutSetEntry set) onCorrect;
  final Future<void> Function(WorkoutSetEntry set) onDelete;

  @override
  Widget build(BuildContext context) {
    final header = AppTypography.labelMono.copyWith(
      color: AppColors.darkTextSecondary,
    );
    final timed = exercise.timed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: ExerciseSetColumns.rank,
                  child: Text(
                    'SÉRIE',
                    textAlign: TextAlign.center,
                    style: header,
                  ),
                ),
                Expanded(
                  child: Text(timed ? 'DURÉE' : 'CHARGE', style: header),
                ),
                Expanded(
                  child: Text(
                    timed ? 'DISTANCE' : 'RÉPÉTITIONS',
                    style: header,
                  ),
                ),
                const SizedBox(width: ExerciseSetColumns.status),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
        for (final (index, set) in exercise.sets.indexed) ...[
          const Divider(height: 1, color: AppColors.rowDivider),
          if (editing)
            // Un seul nœud : la valeur de la ligne, puis ce qu'on peut en faire.
            MergeSemantics(
              child: Semantics(
                button: true,
                hint: timed
                    ? 'Appui long pour supprimer'
                    : 'Toucher pour corriger, appui long pour supprimer',
                // La feuille de correction ne connaît que charge et
                // répétitions : sur une série chronométrée, elle ajouterait
                // une charge à une course. Suppression seule.
                onTap: timed ? null : () => onCorrect(set),
                onLongPress: () => onDelete(set),
                child: InkWell(
                  onTap: timed ? null : () => onCorrect(set),
                  onLongPress: () => onDelete(set),
                  borderRadius: AppRadius.mdAll,
                  child: ExerciseSetRow(
                    position: index + 1,
                    set: set,
                    finished: true,
                  ),
                ),
              ),
            )
          else
            ExerciseSetRow(position: index + 1, set: set, finished: true),
        ],
        if (editing)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Text(
              timed
                  ? 'Appui long sur une série pour la supprimer.'
                  : 'Touche une série pour la corriger, appui long pour la '
                        'supprimer.',
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
