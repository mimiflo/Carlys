import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> addSet(AddSetInput input) =>
      _ref.read(workoutRepositoryProvider).addSet(input);

  Future<void> deleteSet(String setId) =>
      _ref.read(workoutRepositoryProvider).deleteSet(setId);

  Future<void> complete(String sessionId) =>
      _ref.read(workoutRepositoryProvider).completeWorkout(sessionId);

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
