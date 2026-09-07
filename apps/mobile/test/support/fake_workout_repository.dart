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

  /// Conflits tranchés, dans l'ordre : `(séance, choix)`.
  final List<(String, WorkoutConflictResolution)> resolvedConflicts = [];

  /// Ce que jette le prochain `resolveCloseConflict` : une `AppException`
  /// (hors ligne…), mais aussi une `Error` — sans source distante câblée,
  /// `WorkoutConflictActions.takeServer` jette une `StateError` nue.
  Object? conflictResolutionFailure;

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

  /// Nombre de rejeux demandés par l'utilisateur.
  int retryFailedSyncCalls = 0;

  /// Ce que jette le prochain `retryFailedSync`, s'il doit échouer.
  Object? retryFailedSyncFailure;

  @override
  Future<void> retryFailedSync() async {
    retryFailedSyncCalls++;
    final failure = retryFailedSyncFailure;
    if (failure != null) {
      throw failure;
    }
    final current = active;
    if (current != null) {
      // Rejeu accepté : la séance repasse « en attente ».
      _publish(
        WorkoutWithSets(
          session: WorkoutInfo(
            id: current.session.id,
            name: current.session.name,
            status: current.session.status,
            startedAt: current.session.startedAt,
            endedAt: current.session.endedAt,
            durationSeconds: current.session.durationSeconds,
            templateId: current.session.templateId,
            templateName: current.session.templateName,
            syncState: LocalSyncState.pending,
          ),
          sets: current.sets,
        ),
      );
    }
  }

  @override
  Future<void> restoreSessions() async {}

  @override
  Future<void> resolveCloseConflict(
    String sessionId,
    WorkoutConflictResolution resolution,
  ) async {
    final failure = conflictResolutionFailure;
    if (failure != null) {
      throw failure;
    }
    resolvedConflicts.add((sessionId, resolution));
    final current = active;
    if (current != null && current.session.id == sessionId) {
      // Tranché : la séance n'est plus en conflit.
      _publish(
        WorkoutWithSets(
          session: WorkoutInfo(
            id: current.session.id,
            name: current.session.name,
            status: current.session.status,
            startedAt: current.session.startedAt,
            endedAt: current.session.endedAt,
            durationSeconds: current.session.durationSeconds,
            templateId: current.session.templateId,
            templateName: current.session.templateName,
            syncState: resolution == WorkoutConflictResolution.takeServer
                ? LocalSyncState.synced
                : LocalSyncState.pending,
          ),
          sets: current.sets,
        ),
      );
    }
  }

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
