import '../entities/exercise.dart';

/// Filtres de la bibliothèque d'exercices.
class ExercisesFilters {
  const ExercisesFilters({
    this.search,
    this.muscleGroupSlug,
    this.difficulty,
  });

  final String? search;
  final String? muscleGroupSlug;
  final ExerciseDifficulty? difficulty;

  ExercisesFilters copyWith({
    String? Function()? search,
    String? Function()? muscleGroupSlug,
    ExerciseDifficulty? Function()? difficulty,
  }) {
    return ExercisesFilters(
      search: search == null ? this.search : search(),
      muscleGroupSlug:
          muscleGroupSlug == null ? this.muscleGroupSlug : muscleGroupSlug(),
      difficulty: difficulty == null ? this.difficulty : difficulty(),
    );
  }
}

abstract interface class ExercisesRepository {
  Future<ExercisesPage> list({ExercisesFilters filters, String? cursor});

  Future<ExerciseDetail> byIdOrSlug(String idOrSlug);

  Future<List<MuscleGroupRef>> muscleGroups();
}
