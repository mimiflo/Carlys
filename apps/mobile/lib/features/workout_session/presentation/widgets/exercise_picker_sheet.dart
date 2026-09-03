import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../exercises/data/repositories/exercises_repository_impl.dart';
import '../../../exercises/domain/entities/exercise.dart' as catalog;
import '../../../exercises/domain/repositories/exercises_repository.dart';

/// Exercice choisi pour la prochaine série.
class PickedExercise {
  const PickedExercise({required this.name, this.exerciseId});

  final String? exerciseId;
  final String name;
}

/// Feuille de sélection d'exercice depuis le catalogue (avec recherche).
Future<PickedExercise?> showExercisePickerSheet(BuildContext context) {
  return showAppSheet<PickedExercise>(
    context,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.85,
      child: _ExercisePicker(),
    ),
  );
}

final _pickerResultsProvider = FutureProvider.autoDispose
    .family<List<catalog.ExerciseSummary>, String>((ref, search) {
  return ref
      .watch(exercisesRepositoryProvider)
      .list(filters: ExercisesFilters(search: search.isEmpty ? null : search))
      .then((page) => page.items);
});

class _ExercisePicker extends ConsumerStatefulWidget {
  const _ExercisePicker();

  @override
  ConsumerState<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<_ExercisePicker> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(_pickerResultsProvider(_search));
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choisir un exercice', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppSearchField(
              controller: _searchController,
              hint: 'Rechercher un exercice',
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: results.when(
                loading: () => const AppLoadingIndicator(),
                error: (_, __) => AppErrorState(
                  title: 'Catalogue indisponible',
                  message: 'Tu peux réessayer ou saisir un exercice libre.',
                  onRetry: () =>
                      ref.invalidate(_pickerResultsProvider(_search)),
                ),
                data: (exercises) => ListView.separated(
                  itemCount: exercises.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return ListTile(
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.mdAll,
                      ),
                      tileColor: theme.colorScheme.surfaceContainerHighest,
                      title: Text(exercise.name),
                      subtitle: exercise.primaryMuscleGroup == null
                          ? null
                          : Text(exercise.primaryMuscleGroup!.name),
                      onTap: () => Navigator.of(context).pop(
                        PickedExercise(
                          exerciseId: exercise.id,
                          name: exercise.name,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Exercice libre (hors catalogue)',
              variant: AppButtonVariant.ghost,
              isExpanded: true,
              onPressed: () async {
                final name = await _promptFreeExercise(context);
                if (name != null && context.mounted) {
                  Navigator.of(context).pop(PickedExercise(name: name));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _promptFreeExercise(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Exercice libre'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 120,
        decoration: const InputDecoration(hintText: 'Nom de l’exercice'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final name = controller.text.trim();
            Navigator.of(dialogContext).pop(name.isEmpty ? null : name);
          },
          child: const Text('Choisir'),
        ),
      ],
    ),
  );
}
