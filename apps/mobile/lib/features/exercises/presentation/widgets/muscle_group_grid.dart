import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/exercise_library_controller.dart';
import 'muscle_group_card.dart';

/// Porte d'entrée de la bibliothèque : on choisit d'abord un muscle.
///
/// Douze groupes en pastilles défilantes n'en montraient que trois ; en
/// grille, ils se voient tous et l'on sait ce que contient le catalogue avant
/// d'y entrer. Les groupes viennent du référentiel de l'API — seules les
/// images sont embarquées.
class MuscleGroupGrid extends ConsumerWidget {
  const MuscleGroupGrid({super.key});

  static const int columns = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(muscleGroupsProvider);
    final controller = ref.read(exerciseLibraryControllerProvider.notifier);
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return groups.when(
      loading: () => const AppLoadingIndicator(label: 'Chargement des groupes'),
      error: (error, _) => AppErrorState(
        title: 'Impossible de charger les groupes',
        message: 'Vérifiez votre connexion puis réessayez.',
        onRetry: () => ref.invalidate(muscleGroupsProvider),
      ),
      data: (data) => GridView.count(
        crossAxisCount: columns,
        childAspectRatio: MuscleGroupCard.aspectRatio,
        mainAxisSpacing: AppSpacing.gapTile,
        crossAxisSpacing: AppSpacing.gapTile,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          bottomInset + AppSpacing.md,
        ),
        children: [
          // « Tous » ouvre le catalogue entier : la grille ne doit pas
          // enfermer l'utilisateur dans un muscle pour voir un mouvement.
          MuscleGroupCard(
            label: 'Tous les mouvements',
            slug: null,
            onTap: () {
              ref.read(exerciseCatalogueOpenProvider.notifier).state = true;
              controller.setMuscleGroup(null);
            },
          ),
          for (final group in data)
            MuscleGroupCard(
              label: group.name,
              slug: group.slug,
              onTap: () => controller.setMuscleGroup(group.slug),
            ),
        ],
      ),
    );
  }
}
