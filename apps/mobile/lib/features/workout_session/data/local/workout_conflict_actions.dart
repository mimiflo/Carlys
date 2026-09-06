import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/synchronization/sync_conflict_resolver.dart';
import '../datasources/workout_session_remote_data_source.dart';
import '../repositories/workout_session_downloader.dart';

/// Les deux gestes de l'utilisateur devant une séance en conflit de
/// clôture (« clôturée autrement sur un autre appareil »).
///
/// Aucune des deux voies ne perd une série : la version serveur remplace la
/// copie locale mais les séries non acquittées restent ; la version locale
/// est rejouée telle quelle, et si le serveur la refuse encore, la séance
/// passe en échec visible plutôt que de redemander.
class WorkoutConflictActions {
  const WorkoutConflictActions({
    required AppDatabase database,
    required this._remote,
  }) : _db = database;

  final AppDatabase _db;
  final WorkoutSessionRemoteDataSource? _remote;

  /// Rapatrie la version serveur (séance, séries, plan) et oublie la
  /// clôture locale refusée. Jette l'`AppException` de la lecture distante
  /// (hors ligne, serveur indisponible) : l'écran la montre, rien n'est
  /// modifié.
  Future<void> takeServer(String sessionId) async {
    final remote = _remote;
    if (remote == null) {
      throw StateError('Aucune source distante : rien à rapatrier.');
    }
    final detail = await remote.detail(sessionId);
    await _db.transaction(() async {
      await WorkoutSessionDownloader(
        database: _db,
        remote: remote,
      ).write(detail);
      await (_db.delete(_db.syncOperations)..where(
            (op) =>
                op.entityId.equals(sessionId) & op.status.equals('conflict'),
          ))
          .go();
    });
  }

  /// Rejoue la clôture locale, marquée comme arbitrée : le moteur ne
  /// reposera pas la question si le serveur refuse encore.
  Future<void> keepLocal(String sessionId) async {
    await _db.transaction(() async {
      final operations =
          await (_db.select(_db.syncOperations)..where(
                (op) =>
                    op.entityId.equals(sessionId) &
                    op.status.equals('conflict'),
              ))
              .get();
      for (final operation in operations) {
        final payload = jsonDecode(operation.payload) as Map<String, dynamic>;
        payload[syncResolutionKey] = syncKeepLocalResolution;
        await (_db.update(
          _db.syncOperations,
        )..where((op) => op.id.equals(operation.id))).write(
          SyncOperationsCompanion(
            payload: Value(jsonEncode(payload)),
            status: const Value('pending'),
            error: const Value(null),
            attemptCount: const Value(0),
            serverErrorCount: const Value(0),
            lastAttemptAt: const Value(null),
          ),
        );
      }
      await (_db.update(
        _db.localWorkoutSessions,
      )..where((row) => row.id.equals(sessionId))).write(
        const LocalWorkoutSessionsCompanion(syncStatus: Value('pending')),
      );
    });
  }
}
