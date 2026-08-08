import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../progress/domain/entities/progress.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../data/repositories/exercises_repository_impl.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/repositories/exercises_repository.dart';

/// État de la bibliothèque : liste accumulée + filtres + pagination.
class ExerciseLibraryState {
  const ExerciseLibraryState({
    required this.items,
    required this.filters,
    required this.hasMore,
    required this.nextCursor,
    required this.isLoadingMore,
  });

  const ExerciseLibraryState.initial()
      : items = const [],
        filters = const ExercisesFilters(),
        hasMore = false,
        nextCursor = null,
        isLoadingMore = false;

  final List<ExerciseSummary> items;
  final ExercisesFilters filters;
  final bool hasMore;
  final String? nextCursor;
  final bool isLoadingMore;

  ExerciseLibraryState copyWith({
    List<ExerciseSummary>? items,
    ExercisesFilters? filters,
    bool? hasMore,
    String? Function()? nextCursor,
    bool? isLoadingMore,
  }) {
    return ExerciseLibraryState(
      items: items ?? this.items,
      filters: filters ?? this.filters,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor == null ? this.nextCursor : nextCursor(),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Bibliothèque d'exercices : première page en AsyncValue, pages suivantes
/// fusionnées, recherche débouncée, filtres exclusifs.
class ExerciseLibraryController
    extends AutoDisposeAsyncNotifier<ExerciseLibraryState> {
  static const searchDebounce = Duration(milliseconds: 350);

  Timer? _debounce;
  ExercisesFilters _filters = const ExercisesFilters();

  @override
  Future<ExerciseLibraryState> build() async {
    ref.onDispose(() => _debounce?.cancel());
    return _loadFirstPage();
  }

  Future<ExerciseLibraryState> _loadFirstPage() async {
    final page =
        await ref.read(exercisesRepositoryProvider).list(filters: _filters);
    return ExerciseLibraryState(
      items: page.items,
      filters: _filters,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
      isLoadingMore: false,
    );
  }

  Future<void> _reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadFirstPage);
  }

  void setSearch(String search) {
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      final trimmed = search.trim();
      _filters = _filters.copyWith(
        search: () => trimmed.isEmpty ? null : trimmed,
      );
      unawaited(_reload());
    });
  }

  Future<void> setMuscleGroup(String? slug) {
    _filters = _filters.copyWith(muscleGroupSlug: () => slug);
    return _reload();
  }

  Future<void> setDifficulty(ExerciseDifficulty? difficulty) {
    _filters = _filters.copyWith(difficulty: () => difficulty);
    return _reload();
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.nextCursor == null) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref
          .read(exercisesRepositoryProvider)
          .list(filters: _filters, cursor: current.nextCursor);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
          nextCursor: () => page.nextCursor,
          isLoadingMore: false,
        ),
      );
    } on Exception {
      // La page suivante a échoué : on garde la liste actuelle utilisable.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final exerciseLibraryControllerProvider = AsyncNotifierProvider.autoDispose<
    ExerciseLibraryController, ExerciseLibraryState>(
  ExerciseLibraryController.new,
);

/// Référentiel des groupes musculaires (pour les filtres).
final muscleGroupsProvider =
    FutureProvider.autoDispose<List<MuscleGroupRef>>((ref) {
  return ref.watch(exercisesRepositoryProvider).muscleGroups();
});

/// Fiche détaillée d'un exercice.
final exerciseDetailProvider =
    FutureProvider.autoDispose.family<ExerciseDetail, String>((ref, idOrSlug) {
  return ref.watch(exercisesRepositoryProvider).byIdOrSlug(idOrSlug);
});

/// Clé d'un exercice pour la sélection de ses records : l'API historique
/// rattache un record par identifiant quand il existe, par nom sinon.
typedef ExerciseRecordsKey = ({String id, String name});

/// Records personnels de l'utilisateur sur un exercice donné (liste vide
/// tant que les records ne sont pas chargés — jamais de valeur inventée).
final exerciseRecordsProvider = Provider.autoDispose
    .family<List<PersonalRecordEntry>, ExerciseRecordsKey>((ref, key) {
  final all = ref.watch(personalRecordsProvider).valueOrNull ??
      const <PersonalRecordEntry>[];
  return all
      .where(
        (record) =>
            record.exerciseId == key.id || record.exerciseName == key.name,
      )
      .toList();
});
