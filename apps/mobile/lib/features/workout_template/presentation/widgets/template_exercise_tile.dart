import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/template_draft.dart';
import 'planned_set_row.dart';

/// Une **ligne d'exercice** de l'éditeur : repliée elle résume le programme
/// (« 4 séries · 8 reps à 70 kg »), dépliée elle montre chaque série prévue.
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

  /// Poignée de réordonnancement fournie par la liste (elle seule sait quel
  /// index elle déplace).
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
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
            const Divider(height: 1, color: AppColors.darkBorder),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0;
                      index < exercise.sets.length;
                      index++) ...[
                    if (index > 0) const SizedBox(height: AppSpacing.xs),
                    PlannedSetRow(
                      position: index + 1,
                      set: exercise.sets[index],
                      onChanged: (set) => onChangeSet(index, set),
                      onRemove: () => onRemoveSet(index),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(
                    label: 'Ajouter une série',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    icon: AppIcons.add,
                    isExpanded: true,
                    onPressed: onAddSet,
                    semanticLabel: 'Ajouter une série à ${exercise.name}',
                  ),
                  Center(
                    child: TextButton(
                      onPressed: onRemove,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.logout,
                        textStyle: AppTypography.label,
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

/// Ligne repliée : poignée, nom, résumé du programme et chevron.
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
      label: 'Exercice ${formatThousands(position)} : ${exercise.name}, '
          '${summarize(exercise)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: AppRadius.cardSecondaryAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                dragHandle,
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.subheading.copyWith(
                          fontSize: 14,
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        summarize(exercise).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMono
                            .copyWith(color: AppColors.darkTextTertiary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 22,
                  color: AppColors.darkTextTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
