import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/exercise_library_controller.dart';
import '../widgets/exercise_catalog_list.dart';
import '../widgets/exercise_library_header.dart';
import '../widgets/muscle_group_grid.dart';
import '../widgets/selected_group_bar.dart';

/// Bibliothèque d'exercices, en **deux étages** : on choisit d'abord un
/// groupe musculaire, puis on voit ses mouvements.
///
/// Douze groupes en pastilles défilantes n'en montraient que trois à la fois.
/// La grille les montre tous, et la liste ne s'ouvre qu'une fois le terrain
/// choisi. La recherche, elle, court-circuite les deux étages : chercher un
/// nom ne suppose pas de savoir quel muscle il travaille.
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

  /// Nom du groupe choisi, pour le titre de la liste. `null` quand la liste
  /// est ouverte sans groupe (catalogue entier ou recherche).
  String? _groupName(String? slug) {
    if (slug == null) return null;
    final groups = ref.watch(muscleGroupsProvider).valueOrNull;
    if (groups == null) return null;
    for (final group in groups) {
      if (group.slug == slug) return group.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(exerciseLibraryControllerProvider);
    final filters = library.valueOrNull?.filters;
    final selectedSlug = filters?.muscleGroupSlug;
    final searching = (filters?.search ?? '').isNotEmpty;
    final catalogueOpen = ref.watch(exerciseCatalogueOpenProvider);
    final showList = searching || selectedSlug != null || catalogueOpen;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xs,
                AppSpacing.gutter,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ExerciseLibraryHeader(),
                  const SizedBox(height: AppSpacing.gapRow),
                  AppSearchField(
                    controller: _searchController,
                    hint: 'Rechercher un mouvement…',
                    semanticLabel: 'Rechercher un mouvement',
                    onChanged: (value) => ref
                        .read(exerciseLibraryControllerProvider.notifier)
                        .setSearch(value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gapRow),
            // La barre de retour n'apparaît QUE sur une liste atteinte depuis
            // la grille : pendant une recherche, on n'est venu de nulle part.
            if (showList && !searching) ...[
              SelectedGroupBar(
                title: _groupName(selectedSlug) ?? 'Tous les mouvements',
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Expanded(
              child: showList
                  ? library.when(
                      loading: () => const AppLoadingIndicator(
                        label: 'Chargement des exercices',
                      ),
                      error: (error, _) => AppErrorState(
                        title: 'Impossible de charger la bibliothèque',
                        message: 'Vérifiez votre connexion puis réessayez.',
                        onRetry: () =>
                            ref.invalidate(exerciseLibraryControllerProvider),
                      ),
                      data: (state) => ExerciseCatalogList(state: state),
                    )
                  : const MuscleGroupGrid(),
            ),
          ],
        ),
      ),
    );
  }
}
