import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../data/repositories/workout_repository_impl.dart';
import '../../domain/entities/workout.dart';

/// Séance en cours (au plus une), en temps réel depuis la base locale.
final activeWorkoutProvider = StreamProvider<WorkoutWithSets?>((ref) {
  return ref.watch(workoutRepositoryProvider).watchActiveWorkout();
});

/// Historique local, plus récentes d'abord.
final workoutHistoryProvider = StreamProvider<List<WorkoutHistoryEntry>>((ref) {
  return ref.watch(workoutRepositoryProvider).watchHistory();
});

final workoutDetailProvider = FutureProvider.autoDispose
    .family<WorkoutWithSets?, String>((ref, sessionId) {
      return ref.watch(workoutRepositoryProvider).workoutDetail(sessionId);
    });

/// Nombre de séances passées inspectées pour retrouver une performance :
/// au-delà, le rappel « PRÉCÉDENT … » n'a plus de valeur d'entraînement.
const int _inspectedPastSessions = 8;

/// Dernière performance enregistrée pour un exercice, séances passées
/// comprises. `null` quand l'exercice n'a jamais été chargé/répété.
final previousPerformanceProvider = FutureProvider.autoDispose
    .family<WorkoutSetEntry?, String>((ref, exerciseName) async {
      final repository = ref.watch(workoutRepositoryProvider);
      final history = await ref.watch(workoutHistoryProvider.future);

      for (final entry in history.take(_inspectedPastSessions)) {
        final detail = await repository.workoutDetail(entry.session.id);
        if (detail == null) {
          continue;
        }
        final matches = detail.sets
            .where(
              (set) =>
                  set.exerciseName == exerciseName &&
                  set.reps != null &&
                  set.weightKg != null,
            )
            .toList();
        if (matches.isNotEmpty) {
          return matches.last;
        }
      }
      return null;
    });

/// Actions de séance — unique point d'entrée des écrans vers le domaine.
class WorkoutActions {
  const WorkoutActions(this._ref);

  final Ref _ref;

  Future<String> start({String? name}) =>
      _ref.read(workoutRepositoryProvider).startWorkout(name: name);

  /// Reprend la séance en cours, ou en ouvre une — et rend son identifiant.
  ///
  /// La décision « reprendre ou démarrer » est une règle du domaine, pas une
  /// affaire d'écran : deux widgets la rejouaient chacun à sa façon, sur le
  /// CACHE de `activeWorkoutProvider`. Ce cache peut être en échec alors
  /// qu'une séance existe (flux Drift terminé sur erreur, provider non
  /// `autoDispose`, reprise manuelle offerte sur le seul écran de séance) :
  /// ils lisaient alors `null`, appelaient `start()`, et prenaient un
  /// `StateError` que personne n'attrapait.
  ///
  /// Ici l'état vient de la base, et la course est rattrapée : si une séance
  /// démarre entre la lecture et l'ouverture — l'accueil, le coach ou un
  /// modèle peuvent le faire —, on rejoint celle-là au lieu de perdre le
  /// geste. C'est ce que `templates_screen` était seul à faire.
  Future<String> currentOrStart() async {
    final repository = _ref.read(workoutRepositoryProvider);
    final ouverte = await repository.activeWorkoutId();
    if (ouverte != null) {
      return ouverte;
    }
    try {
      return await repository.startWorkout();
    } on StateError {
      final apparue = await repository.activeWorkoutId();
      if (apparue == null) {
        rethrow;
      }
      return apparue;
    }
  }

  /// Enregistre une série sur la séance en cours, en l'ouvrant s'il le faut.
  ///
  /// La série n'est connue qu'une fois la séance choisie : d'où le
  /// constructeur passé en argument plutôt qu'un `AddSetInput` déjà bâti
  /// autour d'un identifiant que l'appelant n'a pas.
  Future<String> addSetToCurrentOrStart(
    AddSetInput Function(String sessionId) serie,
  ) async {
    final sessionId = await currentOrStart();
    await addSet(serie(sessionId));
    return sessionId;
  }

  Future<void> addSet(AddSetInput input) =>
      _ref.read(workoutRepositoryProvider).addSet(input);

  Future<void> deleteSet(String setId) =>
      _ref.read(workoutRepositoryProvider).deleteSet(setId);

  /// Clôt la séance, puis redemande les records.
  ///
  /// La clôture est LE moment où le serveur les recalcule (Étape 5). Sans
  /// cette invalidation ils restaient ceux du lancement de l'application :
  /// `personalRecordsProvider` est bien `autoDispose`, mais deux Provider
  /// permanents l'épinglent, donc il n'était jamais rejoué. On battait un
  /// record et rien ne bougeait, ni dans Progrès, ni dans la vitrine, ni
  /// dans « Dernière récompense » — jusqu'au redémarrage de l'application.
  ///
  /// Hors ligne, l'invalidation ne fait rien perdre : depuis Riverpod 2, la
  /// valeur précédente est conservée pendant le rechargement comme en cas
  /// d'échec, donc l'écran continue d'afficher les derniers records connus.
  Future<void> complete(String sessionId) async {
    await _ref.read(workoutRepositoryProvider).completeWorkout(sessionId);
    _ref.invalidate(personalRecordsProvider);
  }

  Future<void> abandon(String sessionId) =>
      _ref.read(workoutRepositoryProvider).abandonWorkout(sessionId);

  /// Rejoue ce que la synchronisation a mis de côté, puis recharge le détail
  /// de la séance d'où le geste est parti.
  Future<void> retryFailedSync(String sessionId) async {
    await _ref.read(workoutRepositoryProvider).retryFailedSync();
    _ref.invalidate(workoutDetailProvider(sessionId));
  }

  /// Tranche une séance en conflit de clôture, puis recharge son détail.
  Future<void> resolveConflict(
    String sessionId,
    WorkoutConflictResolution resolution,
  ) async {
    await _ref
        .read(workoutRepositoryProvider)
        .resolveCloseConflict(sessionId, resolution);
    _ref.invalidate(workoutDetailProvider(sessionId));
    // Trancher un conflit de clôture, c'est clôturer : mêmes records à
    // redemander que dans `complete`.
    _ref.invalidate(personalRecordsProvider);
  }
}

final workoutActionsProvider = Provider<WorkoutActions>(WorkoutActions.new);

/// État du minuteur de repos.
class RestTimerState {
  const RestTimerState({required this.total, required this.remaining});

  final Duration total;
  final Duration remaining;

  double get progress =>
      total.inSeconds == 0 ? 0 : remaining.inSeconds / total.inSeconds;
}

/// Minuteur de repos entre les séries.
class RestTimerController extends Notifier<RestTimerState?> {
  Timer? _timer;

  @override
  RestTimerState? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void start(Duration duration) {
    _timer?.cancel();
    state = RestTimerState(total: duration, remaining: duration);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state;
      if (current == null) {
        _timer?.cancel();
        return;
      }
      final remaining = current.remaining - const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        stop();
      } else {
        state = RestTimerState(total: current.total, remaining: remaining);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }
}

final restTimerProvider =
    NotifierProvider<RestTimerController, RestTimerState?>(
      RestTimerController.new,
    );
