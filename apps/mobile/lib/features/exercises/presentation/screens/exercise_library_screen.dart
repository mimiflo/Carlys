import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';
import '../controllers/exercise_library_controller.dart';
import '../widgets/exercise_card.dart';

/// Bibliothèque d'exercices : recherche, filtres et défilement infini.
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(exerciseLibraryControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bibliothèque d’exercices')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: AppSearchField(
                controller: _searchController,
                hint: 'Rechercher un exercice',
                onChanged: (value) => ref
                    .read(exerciseLibraryControllerProvider.notifier)
                    .setSearch(value),
              ),
            ),
            const _FiltersBar(),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: library.when(
                loading: () => const AppLoadingIndicator(
                  label: 'Chargement des exercices',
                ),
                error: (error, _) => AppErrorState(
                  title: 'Impossible de charger la bibliothèque',
                  message: 'Vérifiez votre connexion puis réessayez.',
                  onRetry: () =>
                      ref.invalidate(exerciseLibraryControllerProvider),
                ),
                data: (state) => _ExerciseList(state: state),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersBar extends ConsumerWidget {
  const _FiltersBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muscleGroups = ref.watch(muscleGroupsProvider);
    final filters =
        ref.watch(exerciseLibraryControllerProvider).valueOrNull?.filters;
    final controller = ref.read(exerciseLibraryControllerProvider.notifier);

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          for (final difficulty in ExerciseDifficulty.values) ...[
            FilterChip(
              label: Text(difficulty.label),
              selected: filters?.difficulty == difficulty,
              onSelected: (selected) =>
                  controller.setDifficulty(selected ? difficulty : null),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          ...muscleGroups.maybeWhen(
            data: (groups) => [
              for (final group in groups) ...[
                FilterChip(
                  label: Text(group.name),
                  selected: filters?.muscleGroupSlug == group.slug,
                  onSelected: (selected) =>
                      controller.setMuscleGroup(selected ? group.slug : null),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
            orElse: () => const <Widget>[],
          ),
        ],
      ),
    );
  }
}

class _ExerciseList extends ConsumerWidget {
  const _ExerciseList({required this.state});

  final ExerciseLibraryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.items.isEmpty) {
      return const AppEmptyState(
        title: 'Aucun exercice trouvé',
        message: 'Essayez d’élargir votre recherche ou de retirer un filtre.',
        icon: AppIcons.search,
      );
    }

    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + bottomInset,
      ),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          // Sentinelle de fin de liste : la page suivante est demandée après
          // le frame (jamais pendant le build).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(exerciseLibraryControllerProvider.notifier).loadMore();
          });
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: AppLoadingIndicator(size: 24),
          );
        }
        final exercise = state.items[index];
        return ExerciseCard(
          exercise: exercise,
          onTap: () => context.push(AppRoutes.exerciseDetail(exercise.slug)),
        );
      },
    );
  }
}
