import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/exercise_library_controller.dart';
import '../widgets/exercise_catalog_list.dart';
import '../widgets/exercise_filters_bar.dart';
import '../widgets/exercise_library_header.dart';

/// Bibliothèque d'exercices (maquette 2d) : titre et filtres avancés,
/// recherche, pastilles de groupes musculaires, puis le catalogue paginé.
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
            const ExerciseFiltersBar(),
            const SizedBox(height: AppSpacing.md),
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
                data: (state) => ExerciseCatalogList(state: state),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
