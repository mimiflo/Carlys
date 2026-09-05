import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/exercise_library_controller.dart';
import 'exercise_card.dart';

/// Catalogue paginé : en-tête compteur + tri, puis les lignes d'exercices
/// avec le fondu de conteneur du bas (maquette 2d).
class ExerciseCatalogList extends ConsumerWidget {
  const ExerciseCatalogList({required this.state, super.key});

  final ExerciseLibraryState state;

  /// Le catalogue est renvoyé par l'API dans l'ordre alphabétique : le tri
  /// affiché décrit l'ordre réel, il n'est pas décoratif.
  static const String sortLabel = 'A → Z';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.items.isEmpty) {
      return const AppEmptyState(
        title: 'Aucun exercice trouvé',
        message: 'Essaie d’élargir ta recherche ou de retirer un filtre.',
        icon: AppIcons.search,
      );
    }

    // Le TOTAL vient du serveur ; le repli « N+ » ne sert plus qu'aux
    // réponses qui ne le portent pas. Sans lui, un groupe de trente-huit
    // mouvements s'annonçait « 12+ » — le nombre de la première page.
    final count = state.total ?? state.items.length;
    final approximate = state.total == null && state.hasMore;
    final title =
        '${formatThousands(count)}${approximate ? '+' : ''} '
        '${count > 1 ? 'mouvements' : 'mouvement'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: AppSectionHeader(title: title, trailing: sortLabel),
        ),
        const SizedBox(height: AppSpacing.gapTile),
        Expanded(child: _PaginatedRows(state: state)),
      ],
    );
  }
}

class _PaginatedRows extends ConsumerWidget {
  const _PaginatedRows({required this.state});

  final ExerciseLibraryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          0,
          AppSpacing.gutter,
          AppSpacing.md + bottomInset,
        ),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.gapTile),
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
