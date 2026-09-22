import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/progress_repository_impl.dart';
import '../../domain/entities/progress.dart';

/// L'état de la frise : ce qu'on a déjà, et s'il en reste.
class TimelineState {
  const TimelineState({
    this.events = const [],
    this.hasMore = true,
    this.loadingMore = false,
    this.cursor,
    this.error,
  });

  final List<ProgressEvent> events;
  final bool hasMore;

  /// Vrai pendant qu'une page SUIVANTE arrive — distinct du chargement
  /// initial, que l'écran rend par son indicateur plein.
  final bool loadingMore;
  final String? cursor;

  /// L'échec de la PAGE SUIVANTE seulement : la première page échoue par
  /// l'`AsyncValue` du provider, qui a déjà son état d'erreur.
  final Object? error;

  TimelineState copyWith({
    List<ProgressEvent>? events,
    bool? hasMore,
    bool? loadingMore,
    String? cursor,
    Object? error,
    bool clearError = false,
  }) => TimelineState(
    events: events ?? this.events,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    cursor: cursor ?? this.cursor,
    error: clearError ? null : (error ?? this.error),
  );
}

/// LA FRISE, page par page.
///
/// Jamais l'historique Drift : il est plafonné à 60 séances au rapatriement,
/// et une frise tronquée à soixante séances mentirait sur deux ans de
/// pratique. C'est une lecture SERVEUR, et elle affiche son erreur hors
/// ligne plutôt qu'un vide.
class TimelineController extends AutoDisposeAsyncNotifier<TimelineState> {
  /// Taille de page. Assez pour remplir un écran et son élan, assez petite
  /// pour que la première page arrive vite.
  static const int pageSize = 30;

  @override
  Future<TimelineState> build() async {
    final page = await ref
        .watch(progressRepositoryProvider)
        .timeline(limit: pageSize, kinds: _kinds);
    return TimelineState(
      events: page.items,
      hasMore: page.hasMore,
      cursor: page.nextCursor,
    );
  }

  List<ProgressEventKind> _kinds = const [];

  /// Change le filtre et RECHARGE depuis le début : garder les pages déjà
  /// lues mêlerait deux filtres dans une même liste.
  Future<void> filter(List<ProgressEventKind> kinds) async {
    _kinds = kinds;
    ref.invalidateSelf();
    await future;
  }

  List<ProgressEventKind> get kinds => _kinds;

  /// La page suivante, s'il y en a une et qu'aucune n'est déjà en route.
  Future<void> loadMore() async {
    final courant = state.valueOrNull;
    if (courant == null || !courant.hasMore || courant.loadingMore) {
      return;
    }
    state = AsyncData(courant.copyWith(loadingMore: true, clearError: true));
    try {
      final page = await ref
          .read(progressRepositoryProvider)
          .timeline(limit: pageSize, cursor: courant.cursor, kinds: _kinds);
      state = AsyncData(
        courant.copyWith(
          events: [...courant.events, ...page.items],
          hasMore: page.hasMore,
          cursor: page.nextCursor,
          loadingMore: false,
        ),
      );
    } catch (error) {
      // La page déjà lue RESTE : perdre deux ans de frise parce que la page
      // suivante n'est pas venue serait une punition pour un réseau qui
      // flanche.
      state = AsyncData(courant.copyWith(loadingMore: false, error: error));
    }
  }
}

final timelineControllerProvider =
    AutoDisposeAsyncNotifierProvider<TimelineController, TimelineState>(
      TimelineController.new,
    );
