/// Catalogue d'exercices de la DÉMONSTRATION (flavor `demo`) — aucun réseau.
library;

import '../features/exercises/domain/entities/exercise.dart';
import '../features/exercises/domain/repositories/exercises_repository.dart';
import 'demo_catalog.dart';

/// Catalogue embarqué : recherche, filtres et pagination réels.
///
/// La liste vient de `assets/demo/catalog.json`, engendré depuis le seed de
/// l'API — voir `demo_catalog.dart`.
class DemoExercisesRepository implements ExercisesRepository {
  static const _pageSize = 6;

  @override
  Future<ExercisesPage> list({
    ExercisesFilters filters = const ExercisesFilters(),
    String? cursor,
  }) async {
    final catalog = await loadDemoCatalog();
    var filtered = List<ExerciseDetail>.from(catalog.exercises);
    final search = filters.search?.toLowerCase();
    if (search != null && search.isNotEmpty) {
      filtered = filtered
          .where((exercise) => exercise.name.toLowerCase().contains(search))
          .toList();
    }
    if (filters.muscleGroupSlug != null) {
      filtered = filtered
          .where(
            (exercise) =>
                exercise.primaryMuscleGroup?.slug == filters.muscleGroupSlug,
          )
          .toList();
    }
    if (filters.difficulty != null) {
      filtered = filtered
          .where((exercise) => exercise.difficulty == filters.difficulty)
          .toList();
    }

    final start = cursor == null
        ? 0
        : filtered.indexWhere((exercise) => exercise.id == cursor) + 1;
    final page = filtered.skip(start).take(_pageSize).toList();
    final hasMore = start + page.length < filtered.length;

    return ExercisesPage(
      items: page,
      nextCursor: hasMore ? page.last.id : null,
      hasMore: hasMore,
      total: filtered.length,
    );
  }

  @override
  Future<ExerciseDetail> byIdOrSlug(String idOrSlug) async {
    final catalog = await loadDemoCatalog();
    return catalog.exercises.firstWhere(
      (exercise) => exercise.id == idOrSlug || exercise.slug == idOrSlug,
    );
  }

  @override
  Future<List<MuscleGroupRef>> muscleGroups() async =>
      (await loadDemoCatalog()).muscleGroups;
}
