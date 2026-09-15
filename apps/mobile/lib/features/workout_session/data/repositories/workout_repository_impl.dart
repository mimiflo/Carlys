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
import '../mappers/workout_mappers.dart';
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
       _rows = WorkoutRowMapper(database),
       _writer = WorkoutSessionWriter(
         database: database,
         uuid: uuid,
         owner: owner,
       );

  final AppDatabase _db;
  final SyncEngine _sync;
  final WorkoutSessionRemoteDataSource? _remote;
  final Uuid _uuid;
  final WorkoutRowMapper _rows;
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
      final workouts = _rows.groupRows(rows);
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
    final setsCount = _db.localWorkoutSets.id.count();
    final totalVolumeKg =
        (_db.localWorkoutSets.reps.cast<double>() *
                _db.localWorkoutSets.weightKg)
            .sum();

    return _requeteHistorique(setsCount, totalVolumeKg)
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => WorkoutHistoryEntry(
                  session: _rows.mapSession(row.readTable(sessions)),
                  setsCount: row.read(setsCount) ?? 0,
                  totalVolumeKg: row.read(totalVolumeKg) ?? 0,
                ),
              )
              .toList(),
        )
        .distinct(_memeHistorique);
  }

  /// La jointure agrégée de l'historique : une ligne par séance close.
  JoinedSelectStatement<HasResultSet, dynamic> _requeteHistorique(
    Expression<int> setsCount,
    Expression<double> totalVolumeKg,
  ) {
    final sessions = _db.localWorkoutSessions;
    final sets = _db.localWorkoutSets;
    return sessions.select().join([
        leftOuterJoin(
          sets,
          sets.sessionId.equalsExp(sessions.id) & sets.deleted.equals(false),
          useColumns: false,
        ),
      ])
      ..addColumns([setsCount, totalVolumeKg])
      ..where(sessions.status.isNotValue(WorkoutStatus.inProgress.apiValue))
      ..groupBy([sessions.id])
      ..orderBy([OrderingTerm.desc(sessions.startedAt)]);
  }

  /// Deux historiques portent-ils la même information ?
  ///
  /// POURQUOI CE COMPARATEUR EXISTE. Drift réémet dès qu'une table LUE est
  /// écrite, sans comparer le résultat. Or la requête d'historique EXCLUT la
  /// séance en cours : valider une série pendant la séance écrit dans
  /// `localWorkoutSets`, donc réémet, alors que l'historique n'a pas bougé
  /// d'un octet.
  ///
  /// Ce qui pend derrière n'est pas gratuit : le flux est PERMANENT (pas
  /// d'`autoDispose`) et toute la chaîne des récompenses — elle aussi
  /// permanente — en dépend, accueil compris. Une séance de soixante séries
  /// déclenchait soixante recalculs complets, et le rapatriement de
  /// l'historique autant qu'il écrivait de séries.
  ///
  /// Comparaison de SURFACE, sur ce que l'écran affiche vraiment : le rang,
  /// l'identité de la séance, son état de synchronisation, et les deux
  /// agrégats. Une égalité de valeur sur toute l'entité serait plus stricte
  /// sans rien garder de plus, et coûterait un `==` à écrire sur trois
  /// classes du domaine.
  static bool _memeHistorique(
    List<WorkoutHistoryEntry> avant,
    List<WorkoutHistoryEntry> apres,
  ) {
    if (identical(avant, apres)) {
      return true;
    }
    if (avant.length != apres.length) {
      return false;
    }
    for (var i = 0; i < avant.length; i++) {
      final a = avant[i].session;
      final b = apres[i].session;
      if (a.id != b.id ||
          a.status != b.status ||
          a.syncState != b.syncState ||
          a.name != b.name ||
          a.startedAt != b.startedAt ||
          a.endedAt != b.endedAt ||
          a.durationSeconds != b.durationSeconds ||
          avant[i].setsCount != apres[i].setsCount ||
          avant[i].totalVolumeKg != apres[i].totalVolumeKg) {
        return false;
      }
    }
    return true;
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

    final workouts = _rows.groupRows(await query.get());
    return workouts.isEmpty ? null : workouts.first;
  }

  // ── Écritures ────────────────────────────────────────────────────────────

  @override
  Future<String?> activeWorkoutId() async {
    final row =
        await (_db.select(_db.localWorkoutSessions)
              ..where(
                (session) =>
                    session.status.equals(WorkoutStatus.inProgress.apiValue),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

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
    // Tout le corps vit dans `WorkoutSessionWriter` : la même écriture sert
    // au chemin « série libre » (ici) et au chemin « série qui honore une
    // prévision du plan », qui doit l'enchaîner au pointage de l'item DANS LA
    // MÊME transaction. La dupliquer aurait donné deux versions du format de
    // la ligne locale et du corps de `set.upsert`.
    await _db.transaction(
      () => _writer.insertSet(
        id: id,
        input: input,
        completedAt: DateTime.now().toUtc(),
      ),
    );

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
      await (_db.update(
        _db.localWorkoutSets,
      )..where((row) => row.id.equals(setId))).write(
        const LocalWorkoutSetsCompanion(
          deleted: Value(true),
          // `pending` AVEC la pierre tombale, et pas seulement elle. Le
          // rapatriement efface les séries `synced` pour reproduire
          // l'état du serveur, et ne protège que ce qui ne lui appartient
          // pas encore (`syncStatus != 'synced'`). Une pierre tombale
          // laissée `synced` était donc effacée comme une ligne du
          // serveur — lequel a toujours la série, puisque le DELETE
          // n'est pas parti — et la série revenait VIVANTE à l'écran.
          syncStatus: Value('pending'),
        ),
      );
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

    await _db.transaction(
      () => _writer.closeSession(
        sessionId: sessionId,
        to: to,
        operationType: operationType,
        endedAt: endedAt,
        durationSeconds: durationSeconds,
      ),
    );

    _poke();
  }

  @override
  Future<void> retryFailedSync() async {
    // `retryRejected` et non `retryExhausted` : la carte s'affiche aussi sur
    // un refus DÉFINITIF, que le rejeu automatique ignore. Le bouton doit
    // ranimer ce cas-là, sinon il ne fait rien du tout.
    await _sync.retryRejected();
    // Attendu, contrairement au `_poke()` des écritures : c'est un geste de
    // l'utilisateur, l'écran doit pouvoir montrer la fin de la tentative.
    await _sync.syncNow();
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
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepositoryImpl(
    database: ref.watch(appDatabaseProvider),
    syncEngine: ref.watch(syncEngineProvider),
    remote: ref.watch(workoutSessionRemoteDataSourceProvider),
    owner: ref.watch(syncOwnerResolverProvider),
  );
});
