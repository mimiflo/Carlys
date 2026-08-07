import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_controllers.dart';

/// Ligne de série (2c) : la série active en accent, les autres en surface.
class ActiveSetRow extends ConsumerWidget {
  const ActiveSetRow({
    required this.set,
    required this.highlighted,
    super.key,
  });

  final WorkoutSetEntry set;
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = [
      if (set.weightKg != null) '${_formatWeight(set.weightKg!)} kg',
      if (set.reps != null) '${set.reps}',
    ].join(' × ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.accentBadgeBg : AppColors.darkSurface,
        borderRadius: AppRadius.listRowAll,
        border: Border.all(
          color:
              highlighted ? AppColors.accentBadgeBorder : AppColors.darkBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  set.exerciseName,
                  style: AppTypography.subheading.copyWith(
                    fontSize: 14,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (set.kind != SetKind.normal) ...[
                      AppPill(label: set.kind.label.toUpperCase(), mono: true),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Text(
                      detail,
                      style: AppTypography.metricS.copyWith(
                        color: highlighted
                            ? AppColors.accent
                            : AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (set.syncState == LocalSyncState.pending)
            const Tooltip(
              message: 'En attente de synchronisation',
              child: Icon(
                AppIcons.offline,
                size: 18,
                color: AppColors.darkTextTertiary,
              ),
            ),
          IconButton(
            tooltip: 'Supprimer la série',
            icon: const Icon(
              AppIcons.delete,
              size: 20,
              color: AppColors.darkTextTertiary,
            ),
            onPressed: () => ref.read(workoutActionsProvider).deleteSet(set.id),
          ),
        ],
      ),
    );
  }
}

String _formatWeight(double weight) => weight == weight.roundToDouble()
    ? weight.toStringAsFixed(0)
    : weight.toStringAsFixed(1);
