import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/exercise_library_controller.dart';

/// Barre de retour aux catégories, au-dessus de la liste d'exercices.
///
/// La bibliothèque a deux étages ; sans cette barre, on saurait qu'on a filtré
/// mais pas comment revenir en arrière — et le seul chemin serait de quitter
/// l'onglet.
class SelectedGroupBar extends ConsumerWidget {
  const SelectedGroupBar({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              ref.read(exerciseCatalogueOpenProvider.notifier).state = false;
              ref
                  .read(exerciseLibraryControllerProvider.notifier)
                  .setMuscleGroup(null);
            },
            icon: const Icon(AppIcons.back),
            color: AppColors.darkTextSecondary,
            tooltip: 'Revenir aux groupes musculaires',
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heading.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
