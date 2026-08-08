import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/exercises/domain/repositories/exercises_repository.dart';

/// Matériel par défaut du catalogue de test : l'API en renvoie toujours au
/// moins un pour les mouvements de renforcement.
const _barbell = EquipmentRef(id: 'eq-barre', slug: 'barre', name: 'Barre');

/// Muscle secondaire par défaut des fiches de test (rôle SECONDARY côté API).
const _secondaryMuscle =
    MuscleGroupRef(id: 'mg-triceps', slug: 'triceps', name: 'Triceps');

ExerciseSummary summary(
  String id,
  String name, {
  String? group,
  List<EquipmentRef> equipment = const [_barbell],
}) =>
    ExerciseSummary(
      id: id,
      slug: name.toLowerCase().replaceAll(' ', '-'),
      name: name,
      difficulty: ExerciseDifficulty.beginner,
      kind: ExerciseKind.strength,
      isPremium: false,
      primaryMuscleGroup: group == null
          ? null
          : MuscleGroupRef(id: 'mg-$group', slug: group, name: group),
      equipment: equipment,
    );

ExerciseDetail detailOf(ExerciseSummary base) => ExerciseDetail(
      id: base.id,
      slug: base.slug,
      name: base.name,
      difficulty: base.difficulty,
      kind: base.kind,
      isPremium: base.isPremium,
      primaryMuscleGroup: base.primaryMuscleGroup,
      equipment: base.equipment,
      description: 'Description de ${base.name}',
      instructions: const ['Première étape', 'Deuxième étape'],
      tags: const ['test'],
      muscles: [
        if (base.primaryMuscleGroup != null)
          ExerciseMuscleLink(
            muscleGroup: base.primaryMuscleGroup!,
            isPrimary: true,
          ),
        const ExerciseMuscleLink(
          muscleGroup: _secondaryMuscle,
          isPrimary: false,
        ),
      ],
    );

/// Implémentation de test : pages de 2 éléments, filtres appliqués en mémoire.
class FakeExercisesRepository implements ExercisesRepository {
  FakeExercisesRepository(this.all, {this.pageSize = 2});

  final List<ExerciseSummary> all;
  final int pageSize;
  final List<ExercisesFilters> receivedFilters = [];
  int listCalls = 0;

  @override
  Future<ExercisesPage> list({
    ExercisesFilters filters = const ExercisesFilters(),
    String? cursor,
  }) async {
    listCalls++;
    receivedFilters.add(filters);

    var filtered = all;
    final search = filters.search?.toLowerCase();
    if (search != null) {
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
    final page = filtered.skip(start).take(pageSize).toList();
    final hasMore = start + page.length < filtered.length;

    return ExercisesPage(
      items: page,
      nextCursor: hasMore ? page.last.id : null,
      hasMore: hasMore,
    );
  }

  @override
  Future<ExerciseDetail> byIdOrSlug(String idOrSlug) async {
    final found = all.firstWhere(
      (exercise) => exercise.id == idOrSlug || exercise.slug == idOrSlug,
    );
    return detailOf(found);
  }

  @override
  Future<List<MuscleGroupRef>> muscleGroups() async {
    return const [
      MuscleGroupRef(id: 'mg-dos', slug: 'dos', name: 'Dos'),
      MuscleGroupRef(id: 'mg-pectoraux', slug: 'pectoraux', name: 'Pectoraux'),
    ];
  }
}
