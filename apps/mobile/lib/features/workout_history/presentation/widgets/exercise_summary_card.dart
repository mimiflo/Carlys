import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../domain/services/exercise_breakdown.dart';
import 'finished_set_actions.dart';
import 'finished_sets_table.dart';

/// Un exercice du bilan de séance : son nom, ses séries et son volume ;
/// déplié, le tableau de ses séries (maquette d'octobre 2026).
///
/// Le crayon passe la carte EN CORRECTION : chaque série se corrige d'un
/// toucher, se supprime d'un appui long. Hors correction, le tableau ne se
/// lit que — déplier une carte pour la relire ne doit pas ouvrir de feuille
/// par mégarde.
class ExerciseSummaryCard extends ConsumerStatefulWidget {
  const ExerciseSummaryCard({
    required this.sessionId,
    required this.exercise,
    this.initiallyExpanded = false,
    super.key,
  });

  final String sessionId;
  final ExerciseBreakdown exercise;
  final bool initiallyExpanded;

  @override
  ConsumerState<ExerciseSummaryCard> createState() =>
      _ExerciseSummaryCardState();
}

class _ExerciseSummaryCardState extends ConsumerState<ExerciseSummaryCard> {
  late bool _expanded = widget.initiallyExpanded;
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            exercise: exercise,
            expanded: _expanded,
            editing: _editing,
            onToggle: () => setState(() {
              _expanded = !_expanded;
              _editing = false;
            }),
            onEdit: () => setState(() => _editing = !_editing),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.rowDivider),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                0,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: FinishedSetsTable(
                exercise: exercise,
                editing: _editing,
                onCorrect: (set) => correctFinishedSet(
                  context,
                  ref,
                  sessionId: widget.sessionId,
                  set: set,
                ),
                onDelete: (set) => deleteFinishedSet(
                  context,
                  ref,
                  sessionId: widget.sessionId,
                  set: set,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.exercise,
    required this.expanded,
    required this.editing,
    required this.onToggle,
    required this.onEdit,
  });

  final ExerciseBreakdown exercise;
  final bool expanded;
  final bool editing;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final summary = _summary(exercise);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(AppIcons.workout, color: AppColors.primaryLight),
            const SizedBox(width: AppSpacing.md),
            // Le nom d'abord : trois cinquièmes de la rangée, la série qui
            // résume se contente du reste et passe à la ligne s'il le faut.
            Expanded(
              flex: 3,
              child: Semantics(
                button: true,
                label: expanded
                    ? '${exercise.name}, $summary. Replier les séries'
                    : '${exercise.name}, $summary, meilleure série '
                          '${_topSet(exercise.topSet)}. Déplier les séries',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: AppTypography.subheading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    Text(
                      summary,
                      style: AppTypography.body.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              IconButton(
                onPressed: onEdit,
                tooltip: editing ? 'Terminer la correction' : 'Corriger',
                isSelected: editing,
                icon: Icon(
                  AppIcons.editOutline,
                  color: editing
                      ? AppColors.primaryLight
                      : AppColors.darkTextSecondary,
                ),
              )
            else
              Flexible(
                flex: 2,
                child: ExcludeSemantics(
                  child: Text(
                    _topSet(exercise.topSet),
                    textAlign: TextAlign.end,
                    style: AppTypography.body.copyWith(
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
              ),
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  expanded ? AppIcons.collapse : AppIcons.expand,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « 4 séries • 2 560 kg », « 3 séries • 24 min » ; les séries seules quand
/// rien ne se cumule (poids du corps).
String _summary(ExerciseBreakdown exercise) {
  final count = exercise.sets.length;
  final series = '${formatThousands(count)} série${count > 1 ? 's' : ''}';
  if (exercise.timed) {
    return '$series • ${formatMinutes(exercise.totalSeconds)}';
  }
  final volume = exercise.volumeKg;
  return volume > 0 ? '$series • ${formatThousands(volume)} kg' : series;
}

/// La série qui résume l'exercice replié : « 40 kg × 10 reps ».
String _topSet(WorkoutSetEntry set) {
  final seconds = set.durationSeconds;
  if (seconds != null) {
    final duration = formatDuration(seconds);
    return '${duration.value} ${duration.unit}';
  }
  return [
    if (set.weightKg != null) '${formatDecimal(set.weightKg!)} kg',
    if (set.reps != null) '${formatThousands(set.reps!)} reps',
  ].join(' × ');
}
