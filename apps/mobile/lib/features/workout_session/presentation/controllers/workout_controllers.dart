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

final workoutDetailProvider =
    FutureProvider.autoDispose.family<WorkoutWithSets?, String>((ref, sessionId) {
  return ref.watch(workoutRepositoryProvider).workoutDetail(sessionId);
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
}

final workoutActionsProvider = Provider<WorkoutActions>(WorkoutActions.new);

/// État du minuteur de repos.
class RestTimerState {
  const RestTimerState({required this.total, required this.remaining});

  final Duration total;
  final Duration remaining;

  double get progress => total.inSeconds == 0
      ? 0
      : remaining.inSeconds / total.inSeconds;
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

final restTimerProvider = NotifierProvider<RestTimerController, RestTimerState?>(
  RestTimerController.new,
);
