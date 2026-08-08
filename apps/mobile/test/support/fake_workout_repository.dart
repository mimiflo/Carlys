import 'dart:async';

import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/domain/repositories/workout_repository.dart';

/// WorkoutRepository de test — aucun accès à Drift ni au réseau.
///
/// Il tient une séance en cours **en mémoire** : démarrer une séance et y
/// ajouter des séries se voient dans `watchActiveWorkout`, exactement comme
/// avec la base locale. C'est ce qui permet aux tests de widgets de dérouler
/// une séance complète.
class FakeWorkoutRepository implements WorkoutRepository {
  WorkoutWithSets? active;
  List<WorkoutHistoryEntry> history = const [];

  /// Séries reçues, dans l'ordre — les tests d'appariement au plan y lisent
  /// les cibles recopiées (`plannedReps` / `plannedWeightKg`).
  final List<AddSetInput> addedSets = [];

  /// Séances closes, par identifiant et par issue.
  final List<String> completed = [];
  final List<String> abandoned = [];

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
  Future<String> startWorkout({
    String? name,
    String? templateId,
    String? templateName,
  }) async {
    const id = 'fake-session';
    _publish(
      WorkoutWithSets(
        session: WorkoutInfo(
          id: id,
          name: name,
          status: WorkoutStatus.inProgress,
          startedAt: DateTime.now().toUtc(),
          syncState: LocalSyncState.pending,
          templateId: templateId,
          templateName: templateName,
        ),
        sets: const [],
      ),
    );
    return id;
  }

  @override
  Future<String> addSet(AddSetInput input) async {
    addedSets.add(input);
    final id = 'fake-set-${addedSets.length}';

    final current = active;
    if (current != null && current.session.id == input.sessionId) {
      _publish(
        WorkoutWithSets(
          session: current.session,
          sets: [
            ...current.sets,
            WorkoutSetEntry(
              id: id,
              exerciseId: input.exerciseId,
              exerciseName: input.exerciseName,
              position: current.sets.length + 1,
              kind: input.kind,
              reps: input.reps,
              weightKg: input.weightKg,
              restSeconds: input.restSeconds,
              plannedReps: input.plannedReps,
              plannedWeightKg: input.plannedWeightKg,
              completedAt: DateTime.now().toUtc(),
              syncState: LocalSyncState.pending,
            ),
          ],
        ),
      );
    }
    return id;
  }

  @override
  Future<void> deleteSet(String setId) async {
    final current = active;
    if (current == null) {
      return;
    }
    _publish(
      WorkoutWithSets(
        session: current.session,
        sets: current.sets.where((set) => set.id != setId).toList(),
      ),
    );
  }

  @override
  Future<void> completeWorkout(String sessionId) async {
    completed.add(sessionId);
    _publish(null);
  }

  @override
  Future<void> abandonWorkout(String sessionId) async {
    abandoned.add(sessionId);
    _publish(null);
  }

  @override
  Future<void> restoreSessions() async {}

  void _publish(WorkoutWithSets? workout) {
    active = workout;
    _activeController.add(workout);
  }
}

/// Rapatriement inerte pour les tests de widgets : sans lui, l'accueil
/// ouvrirait la vraie base Drift pour tirer les séances du serveur.
class NoopAppRestore implements AppRestore {
  @override
  void ensureRestored() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
