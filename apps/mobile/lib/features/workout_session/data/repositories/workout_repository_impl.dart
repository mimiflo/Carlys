import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/synchronization/sync_engine.dart';
import '../../../../core/synchronization/sync_owner.dart';
import '../../domain/entities/workout.dart';
import '../../domain/repositories/workout_repository.dart';
import '../datasources/workout_session_remote_data_source.dart';
import '../local/workout_conflict_actions.dart';
import '../local/workout_session_writer.dart';
import 'workout_session_downloader.dart';

/// Implémentation offline-first : Drift est écrit en premier, chaque mutation
/// enfile une opération idempotente, puis la synchronisation est tentée en
/// arrière-plan (sans jamais bloquer l'interface).
class WorkoutRepositoryImpl implements WorkoutRepository {
  WorkoutRepositoryImpl({
    required AppDatabase database,
    required SyncEngine syncEngine,
    this._remote,
    SyncOwnerResolver? owner,
    Uuid uuid = const Uuid(),
  }) : _db = database,
       _sync = syncEngine,
       _uuid = uuid,
       _writer = WorkoutSessionWriter(
         database: database,
         uuid: uuid,
         owner: owner,
       );

  final AppDatabase _db;
  final SyncEngine _sync;
  final WorkoutSessionRemoteDataSource? _remote;
  final Uuid _uuid;
  final WorkoutSessionWriter _writer;

  // ── Lectures ─────────────────────────────────────────────────────────────

  @override
  Stream<WorkoutWithSets?> watchActiveWorkout() {
    final query =
        _db.select(_db.localWorkoutSessions).join([
          leftOuterJoin(
            _db.localWorkoutSets,
            _db.localWorkoutSets.sessionId.equalsExp(
                  _db.localWorkoutSessions.id,
                ) &
                _db.localWorkoutSets.deleted.equals(false),
          ),
        ])..where(
          _db.localWorkoutSessions.status.equals(
            WorkoutStatus.inProgress.apiValue,
          ),
        );

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

  /// L'historique ne charge JAMAIS les séries : le nombre de séries et le
  /// volume sont agrégés par SQLite (`COUNT`, `SUM(reps × poids)`), une
  /// ligne par séance. Matérialiser chaque série pour n'en garder que deux
  /// nombres faisait croître le coût de chaque émission avec l'historique
  /// entier. Le calcul est le même que [WorkoutWithSets.totalVolumeKg] : une
  /// série sans répétitions ou sans charge ne compte pas dans le volume
  /// (`NULL × x` est `NULL`, que `SUM` ignore), mais compte comme série.
  @override
  Stream<List<WorkoutHistoryEntry>> watchHistory() {
    final sessions = _db.localWorkoutSessions;
    final sets = _db.localWorkoutSets;
    final setsCount = sets.id.count();
    final totalVolumeKg = (sets.reps.cast<double>() * sets.weightKg).sum();

    final query =
        sessions.select().join([
            leftOuterJoin(
              sets,
              sets.sessionId.equalsExp(sessions.id) &
                  sets.deleted.equals(false),
              useColumns: false,
            ),
          ])
          ..addColumns([setsCount, totalVolumeKg])
          ..where(sessions.status.isNotValue(WorkoutStatus.inProgress.apiValue))
          ..groupBy([sessions.id])
          ..orderBy([OrderingTerm.desc(sessions.startedAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => WorkoutHistoryEntry(
              session: _mapSession(row.readTable(sessions)),
              setsCount: row.read(setsCount) ?? 0,
              totalVolumeKg: row.read(totalVolumeKg) ?? 0,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<WorkoutWithSets?> workoutDetail(String sessionId) async {
    final query = _db.select(_db.localWorkoutSessions).join([
      leftOuterJoin(
        _db.localWorkoutSets,
        _db.localWorkoutSets.sessionId.equalsExp(_db.localWorkoutSessions.id) &
            _db.localWorkoutSets.deleted.equals(false),
      ),
    ])..where(_db.localWorkoutSessions.id.equals(sessionId));

    final workouts = _groupRows(await query.get());
    return workouts.isEmpty ? null : workouts.first;
  }

  // ── Écritures ────────────────────────────────────────────────────────────

  @override
  Future<String> startWorkout({
    String? name,
    String? templateId,
    String? templateName,
  }) async {
    await _writer.requireNoActiveSession();

    final id = _uuid.v4();
    final startedAt = DateTime.now().toUtc();

    await _db.transaction(
      () => _writer.insertSession(
        id: id,
        name: name,
        startedAt: startedAt,
        templateId: templateId,
        templateName: templateName,
      ),
    );

    _poke();
    return id;
  }

  @override
  Future<String> addSet(AddSetInput input) async {
    final id = _uuid.v4();
    final completedAt = DateTime.now().toUtc();
    final existing = await (_db.select(
      _db.localWorkoutSets,
    )..where((set) => set.sessionId.equals(input.sessionId))).get();
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
      if (input.plannedReps != null) 'plannedReps': input.plannedReps,
      if (input.plannedWeightKg != null)
        'plannedWeightKg': input.plannedWeightKg,
      // L'appariement au plan voyage AVEC la série : aucune opération
      // supplémentaire, et l'ordre FIFO garantit que le serveur connaît déjà
      // le plan (transmis avec la création de la séance).
      if (input.planItemId != null) 'planItemId': input.planItemId,
      'completedAt': completedAt.toIso8601String(),
    };

    await _db.transaction(() async {
      await _db
          .into(_db.localWorkoutSets)
          .insert(
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
              plannedReps: Value(input.plannedReps),
              plannedWeightKg: Value(input.plannedWeightKg),
              completedAt: completedAt,
            ),
          );
      await _writer.enqueue(
        entityType: 'set',
        entityId: id,
        operationType: 'set.upsert',
        payload: {'sessionId': input.sessionId, 'body': body},
      );
    });

    _poke();
    return id;
  }

  @override
  Future<void> deleteSet(String setId) async {
    await _db.transaction(() async {
      final set = await (_db.select(
        _db.localWorkoutSets,
      )..where((row) => row.id.equals(setId))).getSingleOrNull();
      if (set == null) {
        return; // déjà purgée : rien à supprimer, rien à envoyer
      }
      await (_db.update(_db.localWorkoutSets)
            ..where((row) => row.id.equals(setId)))
          .write(const LocalWorkoutSetsCompanion(deleted: Value(true)));
      await _writer.enqueue(
        entityType: 'set',
        entityId: setId,
        operationType: 'set.delete',
        // `sessionId` ne part pas au serveur : il range l'opération sur la
        // voie de sa séance, derrière la création et les séries qui la
        // précèdent (cf. `syncLaneOf`).
        payload: {'id': setId, 'sessionId': set.sessionId},
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
    final session = await (_db.select(
      _db.localWorkoutSessions,
    )..where((row) => row.id.equals(sessionId))).getSingleOrNull();
    if (session == null ||
        session.status != WorkoutStatus.inProgress.apiValue) {
      return; // déjà clôturée : idempotent côté client aussi
    }

    final endedAt = DateTime.now().toUtc();
    final durationSeconds = endedAt
        .difference(session.startedAt.toUtc())
        .inSeconds;

    await _db.transaction(() async {
      await (_db.update(
        _db.localWorkoutSessions,
      )..where((row) => row.id.equals(sessionId))).write(
        LocalWorkoutSessionsCompanion(
          status: Value(to.apiValue),
          endedAt: Value(endedAt),
          durationSeconds: Value(durationSeconds),
          syncStatus: const Value('pending'),
        ),
      );
      await _writer.enqueue(
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

  // ── Rapatriement depuis le serveur ───────────────────────────────────────

  @override
  Future<void> restoreSessions() async {
    final remote = _remote;
    if (remote == null) {
      return; // aucune source distante (mode démo, tests hors ligne)
    }
    await WorkoutSessionDownloader(database: _db, remote: remote).run();
  }

  @override
  Future<void> resolveCloseConflict(
    String sessionId,
    WorkoutConflictResolution resolution,
  ) async {
    final actions = WorkoutConflictActions(database: _db, remote: _remote);
    switch (resolution) {
      case WorkoutConflictResolution.takeServer:
        await actions.takeServer(sessionId);
      case WorkoutConflictResolution.keepLocal:
        await actions.keepLocal(sessionId);
        _poke();
    }
  }

  // ── Interne ──────────────────────────────────────────────────────────────

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
      // Copie modifiable : une séance sans série retombait sur une liste
      // constante, que le tri faisait planter.
      final sets = [...setsBySession[session.id] ?? const <LocalWorkoutSet>[]]
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
    templateId: row.templateId,
    templateName: row.templateName,
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
    plannedReps: row.plannedReps,
    plannedWeightKg: row.plannedWeightKg,
    completedAt: row.completedAt,
    syncState: LocalSyncState.fromDb(row.syncStatus),
  );
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    syncEngine: ref.watch(syncEngineProvider),
    remote: ref.watch(workoutSessionRemoteDataSourceProvider),
    owner: ref.watch(syncOwnerResolverProvider),
  );
});
