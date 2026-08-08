import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';
import '../controllers/exercise_library_controller.dart';

/// Feuille de filtres avancés, ouverte par l'icône de l'en-tête.
///
/// Seule la difficulté y figure : c'est le seul filtre supplémentaire
/// réellement accepté par l'API (les groupes musculaires sont en pastilles).
Future<void> showExerciseDifficultySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.darkSurfaceAlt,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.cardMain),
      ),
    ),
    builder: (sheetContext) => const _DifficultySheet(),
  );
}

class _DifficultySheet extends ConsumerWidget {
  const _DifficultySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref
        .watch(exerciseLibraryControllerProvider)
        .valueOrNull
        ?.filters
        .difficulty;

    Future<void> choose(ExerciseDifficulty? difficulty) async {
      Navigator.of(context).pop();
      await ref
          .read(exerciseLibraryControllerProvider.notifier)
          .setDifficulty(difficulty);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(title: 'Niveau de difficulté'),
            const SizedBox(height: AppSpacing.sm),
            _DifficultyRow(
              label: 'Tous les niveaux',
              selected: current == null,
              onTap: () => choose(null),
            ),
            for (final difficulty in ExerciseDifficulty.values) ...[
              const SizedBox(height: AppSpacing.xs),
              _DifficultyRow(
                label: difficulty.label,
                selected: current == difficulty,
                onTap: () => choose(difficulty),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      title: label,
      leading: AppIcons.filter,
      leadingTint: selected ? AppColors.accent : AppColors.primaryLight,
      trailing: selected
          ? const Icon(AppIcons.check, size: 20, color: AppColors.accent)
          : null,
      onTap: onTap,
    );
  }
}
