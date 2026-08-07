import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';
import '../controllers/exercise_library_controller.dart';
import '../widgets/exercise_card.dart';

/// Bibliothèque d'exercices (maquette 2d) : compteur en mono, pastilles de
/// filtres, recherche, lignes avec fondu de conteneur en bas.
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
    final loaded = library.valueOrNull;
    final count = loaded == null
        ? null
        : '${loaded.items.length}${loaded.hasMore ? '+' : ''} MOUVEMENTS';

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      'Exercices',
                      style: AppTypography.title
                          .copyWith(color: AppColors.darkTextPrimary),
                    ),
                  ),
                  if (count != null)
                    AppSectionLabel(
                      count,
                      color: AppColors.darkTextTertiary,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
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
    final noMuscleFilter = filters?.muscleGroupSlug == null;

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          AppPill(
            label: 'Tous',
            selected: noMuscleFilter && filters?.difficulty == null,
            onTap: () {
              controller.setMuscleGroup(null);
              controller.setDifficulty(null);
            },
          ),
          const SizedBox(width: AppSpacing.xs),
          ...muscleGroups.maybeWhen(
            data: (groups) => [
              for (final group in groups) ...[
                AppPill(
                  label: group.name,
                  selected: filters?.muscleGroupSlug == group.slug,
                  onTap: () => controller.setMuscleGroup(
                    filters?.muscleGroupSlug == group.slug ? null : group.slug,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
            orElse: () => const <Widget>[],
          ),
          for (final difficulty in ExerciseDifficulty.values) ...[
            AppPill(
              label: difficulty.label,
              selected: filters?.difficulty == difficulty,
              onTap: () => controller.setDifficulty(
                filters?.difficulty == difficulty ? null : difficulty,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
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

    // Fondu de conteneur : le rognage se lit comme un défilement (2d).
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, 0.86, 0.99],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.md,
          AppSpacing.gutter,
          AppSpacing.md + bottomInset,
        ),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            // Sentinelle de fin de liste : la page suivante est demandée
            // après le frame (jamais pendant le build).
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
      ),
    );
  }
}
