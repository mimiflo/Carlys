import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';
import 'exercise_set_row.dart';

/// « Séries de l'exercice » : le tableau des séries faites, de celle en
/// cours et de celles que le programme prévoit encore.
class ExerciseSetsTable extends StatelessWidget {
  const ExerciseSetsTable({
    required this.sets,
    required this.upcomingSets,
    required this.timeMode,
    required this.onDelete,
    this.plannedWeightKg,
    this.plannedReps,
    this.setRank,
    this.setsInExercise,
    super.key,
  });

  /// Séries enregistrées sur l'exercice, dans l'ordre de saisie.
  final List<WorkoutSetEntry> sets;

  /// Séries prévues restant APRÈS celle en cours de saisie.
  final int upcomingSets;

  /// L'exercice se mesure en temps et distance : les colonnes le disent.
  final bool timeMode;

  final double? plannedWeightKg;
  final int? plannedReps;

  /// Le rang de la série proposée et le total prévu, selon le PROGRAMME :
  /// après une série passée, la ligne en cours dit « 3 », comme les cartes
  /// au-dessus. `null` hors modèle.
  final int? setRank;
  final int? setsInExercise;
  final Future<void> Function(String setId) onDelete;

  @override
  Widget build(BuildContext context) {
    final validated = sets.length;
    final rank = setRank ?? validated + 1;
    final total = setsInExercise;
    // Sans programme, le total n'existe pas : on compte ce qui est fait.
    final counter = total == null
        ? '${formatThousands(validated)} validée${validated > 1 ? 's' : ''}'
        : '${formatThousands(validated)} / ${formatThousands(total)} validées';
    final header = AppTypography.labelMono.copyWith(
      color: AppColors.darkTextSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Séries de l’exercice',
                  style: AppTypography.heading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
            ),
            Text(
              counter,
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
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
                        child: Text(timeMode ? 'DURÉE' : 'KG', style: header),
                      ),
                      Expanded(
                        child: Text(
                          timeMode ? 'DISTANCE' : 'REPS',
                          style: header,
                        ),
                      ),
                      const SizedBox(width: ExerciseSetColumns.status),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
              for (final (index, set) in sets.indexed) ...[
                const Divider(height: 1, color: AppColors.rowDivider),
                ExerciseSetRow(
                  position: index + 1,
                  set: set,
                  onDelete: () => onDelete(set.id),
                ),
              ],
              const Divider(height: 1, color: AppColors.rowDivider),
              ExerciseSetRow(
                position: rank,
                current: true,
                plannedWeightKg: timeMode ? null : plannedWeightKg,
                plannedReps: timeMode ? null : plannedReps,
              ),
              for (var index = 0; index < upcomingSets; index++) ...[
                const Divider(height: 1, color: AppColors.rowDivider),
                ExerciseSetRow(position: rank + 1 + index),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
