import 'dart:async';

import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/domain/repositories/workout_repository.dart';

/// WorkoutRepository de test — aucun accès à Drift ni au réseau.
class FakeWorkoutRepository implements WorkoutRepository {
  WorkoutWithSets? active;
  List<WorkoutHistoryEntry> history = const [];

  final _activeController = StreamController<WorkoutWithSets?>.broadcast();

  @override
  Stream<WorkoutWithSets?> watchActiveWorkout() async* {
    yield active;
    yield* _activeController.stream;
  }

  @override
  Stream<List<WorkoutHistoryEntry>> watchHistory() => Stream.value(history);

  @override
  Future<WorkoutWithSets?> workoutDetail(String sessionId) async => active;

  @override
  Future<String> startWorkout({String? name}) async => 'fake-session';

  @override
  Future<void> addSet(AddSetInput input) async {}

  @override
  Future<void> deleteSet(String setId) async {}

  @override
  Future<void> completeWorkout(String sessionId) async {}

  @override
  Future<void> abandonWorkout(String sessionId) async {}
}

/// SyncLifecycle inerte pour les tests de widgets.
class NoopSyncLifecycle implements SyncLifecycle {
  @override
  void ensureStarted() {}

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
