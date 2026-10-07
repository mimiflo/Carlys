import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../utils/template_draft.dart';
import 'planned_sets_table.dart';
import 'set_kind_sheet.dart';

/// Une **ligne d'exercice** de l'éditeur (maquette d'octobre 2026) : repliée
/// elle résume le programme (« 4 séries · 8 reps à 70 kg »), dépliée elle
/// montre le tableau des séries, leur type, l'ajout et le retrait.
class TemplateExerciseTile extends StatelessWidget {
  const TemplateExerciseTile({
    required this.exercise,
    required this.position,
    required this.expanded,
    required this.onToggle,
    required this.onRemove,
    required this.onAddSet,
    required this.onChangeSet,
    required this.onRemoveSet,
    required this.onSetKindForAll,
    required this.dragHandle,
    super.key,
  });

  final DraftExercise exercise;

  /// Rang affiché de la ligne (1 pour la première).
  final int position;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback onAddSet;
  final void Function(int setIndex, DraftSet set) onChangeSet;
  final void Function(int setIndex) onRemoveSet;
  final ValueChanged<SetKind> onSetKindForAll;

  /// Poignée de réordonnancement fournie par la liste (elle seule sait quel
  /// index elle déplace).
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Summary(
            exercise: exercise,
            position: position,
            expanded: expanded,
            onToggle: onToggle,
            dragHandle: dragHandle,
          ),
          if (expanded) ...[
            const Divider(
              height: 1,
              indent: AppSpacing.sm,
              endIndent: AppSpacing.sm,
              color: AppColors.rowDivider,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.xxs,
                AppSpacing.xs,
              ),
              child: PlannedSetsTable(
                exercise: exercise,
                onChangeSet: onChangeSet,
                onRemoveSet: onRemoveSet,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SetKindSelector(
                    sets: exercise.sets,
                    onChoose: onSetKindForAll,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Ajouter une série',
                    variant: AppButtonVariant.secondary,
                    icon: AppIcons.add,
                    isExpanded: true,
                    onPressed: onAddSet,
                    semanticLabel: 'Ajouter une série à ${exercise.name}',
                  ),
                  Center(
                    child: TextButton(
                      onPressed: onRemove,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        textStyle: AppTypography.body,
                      ),
                      child: const Text('Retirer cet exercice'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ligne repliée : poignée, pastille, nom, résumé du programme et chevron.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.exercise,
    required this.position,
    required this.expanded,
    required this.onToggle,
    required this.dragHandle,
  });

  final DraftExercise exercise;
  final int position;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      label:
          'Exercice ${formatThousands(position)} : ${exercise.name}, '
          '${summarize(exercise)}',
      child: InkWell(
        onTap: onToggle,
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              dragHandle,
              const SizedBox(width: AppSpacing.xs),
              const AppIconBadge(
                icon: AppIcons.equipmentDumbbell,
                size: 48,
                color: AppColors.primaryLight,
                background: AppColors.primaryBadgeBg,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: AppTypography.subheading.copyWith(
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        expanded
                            ? _plannedSets(exercise.sets.length)
                            : summarize(exercise),
                        style: AppTypography.body.copyWith(
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(
                expanded ? AppIcons.collapse : AppIcons.expand,
                color: AppColors.primaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « 4 séries prévues » : dépliée, la ligne n'a plus à résumer le tableau.
String _plannedSets(int count) =>
    '${formatThousands(count)} série${count > 1 ? 's' : ''} '
    'prévue${count > 1 ? 's' : ''}';

/// « 4 séries · 8 reps à 70 kg » — la charge n'apparaît que si elle est
/// prévue, et seulement quand toutes les séries visent la même chose.
String summarize(DraftExercise exercise) {
  final sets = exercise.sets;
  final count = sets.length;
  final label = '${formatThousands(count)} série${count > 1 ? 's' : ''}';
  if (sets.isEmpty) {
    return label;
  }

  final reps = sets.first.targetReps;
  final weight = sets.first.targetWeightKg;
  final sameReps = sets.every((set) => set.targetReps == reps);
  final sameWeight = sets.every((set) => set.targetWeightKg == weight);

  if (!sameReps || reps == null) {
    return label;
  }
  final repsLabel = '$label · ${formatThousands(reps)} reps';
  if (!sameWeight || weight == null) {
    return repsLabel;
  }
  return '$repsLabel à ${formatDecimal(weight)} kg';
}
