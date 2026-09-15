import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/debouncer.dart';
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
    this.loadMoreFailed = false,
    this.total,
  });

  const ExerciseLibraryState.initial()
    : items = const [],
      filters = const ExercisesFilters(),
      hasMore = false,
      nextCursor = null,
      isLoadingMore = false,
      loadMoreFailed = false,
      total = null;

  final List<ExerciseSummary> items;
  final ExercisesFilters filters;
  final bool hasMore;
  final String? nextCursor;
  final bool isLoadingMore;

  /// La DERNIÈRE demande de page suivante a échoué.
  ///
  /// Sans ce drapeau, la sentinelle de fin de liste rappelait `loadMore` à
  /// chaque reconstruction : un échec la laissait affichée, la reconstruction
  /// relançait la requête, l'échec la laissait affichée… Une coupure réseau
  /// suffisait donc à lancer une requête par image, indéfiniment, sans qu'un
  /// seul écran ne le dise. La sentinelle propose maintenant de réessayer, et
  /// n'insiste plus toute seule.
  final bool loadMoreFailed;

  /// Total annoncé par le serveur, `null` s'il ne le donne pas.
  final int? total;

  ExerciseLibraryState copyWith({
    List<ExerciseSummary>? items,
    ExercisesFilters? filters,
    bool? hasMore,
    String? Function()? nextCursor,
    bool? isLoadingMore,
    bool? loadMoreFailed,
    int? total,
  }) {
    return ExerciseLibraryState(
      items: items ?? this.items,
      filters: filters ?? this.filters,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor == null ? this.nextCursor : nextCursor(),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      total: total ?? this.total,
    );
  }
}

/// Bibliothèque d'exercices : première page en AsyncValue, pages suivantes
/// fusionnées, recherche débouncée, filtres exclusifs.
class ExerciseLibraryController
    extends AutoDisposeAsyncNotifier<ExerciseLibraryState> {
  /// Le délai vit au cœur : la feuille de sélection d'exercice en séance
  /// a besoin du MÊME, et deux minuteries écrites séparément divergent.
  static const searchDebounce = Debouncer.search;

  final _debounce = Debouncer(delay: searchDebounce);
  ExercisesFilters _filters = const ExercisesFilters();
  bool _disposed = false;

  @override
  Future<ExerciseLibraryState> build() async {
    _disposed = false;
    ref.onDispose(() {
      _debounce.cancel();
      // Poser `state` après la destruction jette : les réponses encore en
      // vol quand l'écran se ferme doivent se laisser tomber sans bruit.
      _disposed = true;
    });
    return _loadFirstPage();
  }

  Future<ExerciseLibraryState> _loadFirstPage() async {
    final page = await ref
        .read(exercisesRepositoryProvider)
        .list(filters: _filters);
    return ExerciseLibraryState(
      items: page.items,
      filters: _filters,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
      isLoadingMore: false,
      total: page.total,
    );
  }

  Future<void> _reload() async {
    // Génération de la demande : `_filters` est remplacé (jamais muté) à
    // chaque changement, son identité date donc chaque réponse. Une réponse
    // dont la génération n'est plus la bonne est simplement abandonnée —
    // sans cette garde, recharger pendant qu'une autre requête est en vol
    // laissait la PREMIÈRE arrivée écraser la seconde.
    final requested = _filters;
    state = const AsyncLoading();
    final next = await AsyncValue.guard(_loadFirstPage);
    if (_disposed || !identical(requested, _filters)) {
      return;
    }
    state = next;
  }

  void setSearch(String search) {
    _debounce.run(() {
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

  /// Charge la page suivante.
  ///
  /// `force` : demandé EXPLICITEMENT par la personne, après un échec. La
  /// sentinelle, elle, ne force jamais — voir [ExerciseLibraryState.loadMoreFailed].
  Future<void> loadMore({bool force = false}) async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.nextCursor == null) {
      return;
    }
    if (current.loadMoreFailed && !force) {
      return;
    }

    // Même garde de génération que `_reload` : si un filtre change pendant
    // que cette page est en vol, la réponse appartient à une liste qui
    // n'existe plus — la fusionner recollerait les résultats de l'ANCIEN
    // filtre sous les puces du nouveau.
    final requested = _filters;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await ref
          .read(exercisesRepositoryProvider)
          .list(filters: requested, cursor: current.nextCursor);
      if (_disposed || !identical(requested, _filters)) {
        return;
      }
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
          total: page.total,
          nextCursor: () => page.nextCursor,
          isLoadingMore: false,
        ),
      );
    } on Exception {
      if (_disposed || !identical(requested, _filters)) {
        return;
      }
      // La page suivante a échoué : on garde la liste actuelle utilisable,
      // et on le DIT — sans quoi la sentinelle redemanderait à chaque image.
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreFailed: true),
      );
    }
  }
}

final exerciseLibraryControllerProvider =
    AsyncNotifierProvider.autoDispose<
      ExerciseLibraryController,
      ExerciseLibraryState
    >(ExerciseLibraryController.new);
