import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/exercise_library_controller.dart';

/// Rangée de pastilles de filtre par groupe musculaire (maquette 2d).
///
/// La pastille active est le seul aplat orange de l'écran ; les groupes
/// proviennent du référentiel de l'API, jamais d'une liste codée en dur.
class ExerciseFiltersBar extends ConsumerWidget {
  const ExerciseFiltersBar({super.key});

  static const double height = 36;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muscleGroups = ref.watch(muscleGroupsProvider);
    final filters =
        ref.watch(exerciseLibraryControllerProvider).valueOrNull?.filters;
    final controller = ref.read(exerciseLibraryControllerProvider.notifier);
    final selectedSlug = filters?.muscleGroupSlug;

    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          AppPill(
            label: 'Tous',
            selected: selectedSlug == null,
            selectedTone: AppPillTone.accentSolid,
            onTap: () => controller.setMuscleGroup(null),
          ),
          ...muscleGroups.maybeWhen(
            data: (groups) => [
              for (final group in groups) ...[
                const SizedBox(width: AppSpacing.xs),
                AppPill(
                  label: group.name,
                  selected: selectedSlug == group.slug,
                  selectedTone: AppPillTone.accentSolid,
                  onTap: () => controller.setMuscleGroup(
                    selectedSlug == group.slug ? null : group.slug,
                  ),
                ),
              ],
            ],
            orElse: () => const <Widget>[],
          ),
        ],
      ),
    );
  }
}
