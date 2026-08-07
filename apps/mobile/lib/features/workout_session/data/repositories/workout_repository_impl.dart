import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/synchronization/sync_engine.dart';
import '../../domain/entities/workout.dart';
import '../../domain/repositories/workout_repository.dart';

/// Implémentation offline-first : Drift est écrit en premier, chaque mutation
/// enfile une opération idempotente, puis la synchronisation est tentée en
/// arrière-plan (sans jamais bloquer l'interface).
class WorkoutRepositoryImpl implements WorkoutRepository {
  WorkoutRepositoryImpl({
    required AppDatabase database,
    required SyncEngine syncEngine,
    Uuid uuid = const Uuid(),
  })  : _db = database,
        _sync = syncEngine,
        _uuid = uuid;

  final AppDatabase _db;
  final SyncEngine _sync;
  final Uuid _uuid;

  // ── Lectures ─────────────────────────────────────────────────────────────

  @override
  Stream<WorkoutWithSets?> watchActiveWorkout() {
    final query = _db.select(_db.localWorkoutSessions).join([
      leftOuterJoin(
        _db.localWorkoutSets,
        _db.localWorkoutSets.sessionId.equalsExp(_db.localWorkoutSessions.id) &
            _db.localWorkoutSets.deleted.equals(false),
      ),
    ])
      ..where(_db.localWorkoutSessions.status.equals(WorkoutStatus.inProgress.apiValue));

    return query.watch().map((rows) {
      final workouts = _groupRows(rows);
      if (workouts.isEmpty) {
        return null;
      }
      workouts.sort(
        (a, b) => b.session.startedAt.compareTo(a.session.startedAt),
      );
      return workouts.first;
    });
  }

  @override
  Stream<List<WorkoutHistoryEntry>> watchHistory() {
    final query = _db.select(_db.localWorkoutSessions).join([
      leftOuterJoin(
        _db.localWorkoutSets,
        _db.localWorkoutSets.sessionId.equalsExp(_db.localWorkoutSessions.id) &
            _db.localWorkoutSets.deleted.equals(false),
      ),
    ])
      ..where(
        _db.localWorkoutSessions.status.isNotValue(WorkoutStatus.inProgress.apiValue),
      );

    return query.watch().map((rows) {
      final workouts = _groupRows(rows)
        ..sort((a, b) => b.session.startedAt.compareTo(a.session.startedAt));
      return workouts
          .map(
            (workout) => WorkoutHistoryEntry(
              session: workout.session,
              setsCount: workout.setsCount,
              totalVolumeKg: workout.totalVolumeKg,
            ),
          )
          .toList();
    });
  }

  @override
  Future<WorkoutWithSets?> workoutDetail(String sessionId) async {
    final query = _db.select(_db.localWorkoutSessions).join([
      leftOuterJoin(
        _db.localWorkoutSets,
        _db.localWorkoutSets.sessionId.equalsExp(_db.localWorkoutSessions.id) &
            _db.localWorkoutSets.deleted.equals(false),
      ),
    ])
      ..where(_db.localWorkoutSessions.id.equals(sessionId));

    final workouts = _groupRows(await query.get());
    return workouts.isEmpty ? null : workouts.first;
  }

  // ── Écritures ────────────────────────────────────────────────────────────

  @override
  Future<String> startWorkout({String? name}) async {
    final active = await (_db.select(_db.localWorkoutSessions)
          ..where(
            (session) => session.status.equals(WorkoutStatus.inProgress.apiValue),
          ))
        .get();
    if (active.isNotEmpty) {
      throw StateError('Une séance est déjà en cours.');
    }

    final id = _uuid.v4();
    final startedAt = DateTime.now().toUtc();

    await _db.transaction(() async {
      await _db.into(_db.localWorkoutSessions).insert(
            LocalWorkoutSessionsCompanion.insert(
              id: id,
              name: Value(name),
              status: WorkoutStatus.inProgress.apiValue,
              startedAt: startedAt,
            ),
          );
      await _enqueue(
        entityType: 'session',
        entityId: id,
        operationType: 'session.create',
        payload: {
          'id': id,
          if (name != null) 'name': name,
          'startedAt': startedAt.toIso8601String(),
        },
      );
    });

    _poke();
    return id;
  }

  @override
  Future<void> addSet(AddSetInput input) async {
    final id = _uuid.v4();
    final completedAt = DateTime.now().toUtc();
    final existing = await (_db.select(_db.localWorkoutSets)
          ..where((set) => set.sessionId.equals(input.sessionId)))
        .get();
    final position = existing.length;

    final body = <String, dynamic>{
      'id': id,
      if (input.exerciseId != null) 'exerciseId': input.exerciseId,
      'exerciseName': input.exerciseName,
      'position': position,
      'kind': input.kind.apiValue,
      if (input.reps != null) 'reps': input.reps,
      if (input.weightKg != null) 'weightKg': input.weightKg,
      if (input.restSeconds != null) 'restSeconds': input.restSeconds,
      if (input.rpe != null) 'rpe': input.rpe,
      'completedAt': completedAt.toIso8601String(),
    };

    await _db.transaction(() async {
      await _db.into(_db.localWorkoutSets).insert(
            LocalWorkoutSetsCompanion.insert(
              id: id,
              sessionId: input.sessionId,
              exerciseId: Value(input.exerciseId),
              exerciseName: input.exerciseName,
              position: position,
              kind: Value(input.kind.apiValue),
              reps: Value(input.reps),
              weightKg: Value(input.weightKg),
              restSeconds: Value(input.restSeconds),
              rpe: Value(input.rpe),
              completedAt: completedAt,
            ),
          );
      await _enqueue(
        entityType: 'set',
        entityId: id,
        operationType: 'set.upsert',
        payload: {'sessionId': input.sessionId, 'body': body},
      );
    });

    _poke();
  }

  @override
  Future<void> deleteSet(String setId) async {
    await _db.transaction(() async {
      await (_db.update(_db.localWorkoutSets)
            ..where((set) => set.id.equals(setId)))
          .write(const LocalWorkoutSetsCompanion(deleted: Value(true)));
      await _enqueue(
        entityType: 'set',
        entityId: setId,
        operationType: 'set.delete',
        payload: {'id': setId},
      );
    });
    _poke();
  }

  @override
  Future<void> completeWorkout(String sessionId) =>
      _closeWorkout(sessionId, WorkoutStatus.completed, 'session.complete');

  @override
  Future<void> abandonWorkout(String sessionId) =>
      _closeWorkout(sessionId, WorkoutStatus.abandoned, 'session.abandon');

  Future<void> _closeWorkout(
    String sessionId,
    WorkoutStatus to,
    String operationType,
  ) async {
    final session = await (_db.select(_db.localWorkoutSessions)
          ..where((row) => row.id.equals(sessionId)))
        .getSingleOrNull();
    if (session == null || session.status != WorkoutStatus.inProgress.apiValue) {
      return; // déjà clôturée : idempotent côté client aussi
    }

    final endedAt = DateTime.now().toUtc();
    final durationSeconds =
        endedAt.difference(session.startedAt.toUtc()).inSeconds;

    await _db.transaction(() async {
      await (_db.update(_db.localWorkoutSessions)
            ..where((row) => row.id.equals(sessionId)))
          .write(
        LocalWorkoutSessionsCompanion(
          status: Value(to.apiValue),
          endedAt: Value(endedAt),
          durationSeconds: Value(durationSeconds),
          syncStatus: const Value('pending'),
        ),
      );
      await _enqueue(
        entityType: 'session',
        entityId: sessionId,
        operationType: operationType,
        payload: {
          'id': sessionId,
          'body': {
            'endedAt': endedAt.toIso8601String(),
            'durationSeconds': durationSeconds,
          },
        },
      );
    });

    _poke();
  }

  // ── Interne ──────────────────────────────────────────────────────────────

  Future<void> _enqueue({
    required String entityType,
    required String entityId,
    required String operationType,
    required Map<String, dynamic> payload,
  }) {
    return _db.into(_db.syncOperations).insert(
          SyncOperationsCompanion.insert(
            id: _uuid.v4(),
            entityType: entityType,
            entityId: entityId,
            operationType: operationType,
            payload: jsonEncode(payload),
            createdAt: DateTime.now().toUtc(),
            idempotencyKey: entityId,
          ),
        );
  }

  void _poke() {
    unawaited(_sync.syncNow());
  }

  List<WorkoutWithSets> _groupRows(List<TypedResult> rows) {
    final sessions = <String, LocalWorkoutSession>{};
    final setsBySession = <String, List<LocalWorkoutSet>>{};

    for (final row in rows) {
      final session = row.readTable(_db.localWorkoutSessions);
      sessions[session.id] = session;
      final set = row.readTableOrNull(_db.localWorkoutSets);
      if (set != null) {
        setsBySession.putIfAbsent(session.id, () => []).add(set);
      }
    }

    return sessions.values.map((session) {
      final sets = (setsBySession[session.id] ?? const [])
        ..sort((a, b) => a.position.compareTo(b.position));
      return WorkoutWithSets(
        session: _mapSession(session),
        sets: sets.map(_mapSet).toList(),
      );
    }).toList();
  }

  WorkoutInfo _mapSession(LocalWorkoutSession row) => WorkoutInfo(
        id: row.id,
        name: row.name,
        status: WorkoutStatus.fromApi(row.status),
        startedAt: row.startedAt,
        endedAt: row.endedAt,
        durationSeconds: row.durationSeconds,
        syncState: LocalSyncState.fromDb(row.syncStatus),
      );

  WorkoutSetEntry _mapSet(LocalWorkoutSet row) => WorkoutSetEntry(
        id: row.id,
        exerciseId: row.exerciseId,
        exerciseName: row.exerciseName,
        position: row.position,
        kind: SetKind.fromApi(row.kind),
        reps: row.reps,
        weightKg: row.weightKg,
        restSeconds: row.restSeconds,
        rpe: row.rpe,
        completedAt: row.completedAt,
        syncState: LocalSyncState.fromDb(row.syncStatus),
      );
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});
