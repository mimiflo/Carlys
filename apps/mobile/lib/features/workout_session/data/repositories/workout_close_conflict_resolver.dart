import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/synchronization/sync_conflict_resolver.dart';
import '../../domain/entities/workout.dart';
import '../datasources/workout_session_remote_data_source.dart';
import '../dto/workout_session_dtos.dart';
import 'workout_session_downloader.dart';

/// Tranche un `409` reçu à la clôture d'une séance en lisant la version du
/// serveur.
///
/// L'API répond 409 uniquement quand la séance est déjà close **avec une
/// autre issue** (terminée ici, abandonnée là-bas, ou l'inverse) : même
/// issue des deux côtés, c'est un rejeu servi en 200. Il reste donc à
/// distinguer la course (le serveur a la même issue au moment où on relit)
/// du vrai désaccord, qui appartient à l'utilisateur.
class WorkoutCloseConflictResolver implements SyncConflictResolver {
  WorkoutCloseConflictResolver({
    required AppDatabase database,
    required WorkoutSessionRemoteDataSource remote,
  }) : _db = database,
       _remote = remote,
       _downloader = WorkoutSessionDownloader(
         database: database,
         remote: remote,
       );

  static const _logger = AppLogger('WorkoutCloseConflictResolver');

  final AppDatabase _db;
  final WorkoutSessionRemoteDataSource _remote;
  final WorkoutSessionDownloader _downloader;

  @override
  Future<SyncConflictVerdict> resolveClose(SyncOperation operation) async {
    final sessionId = operation.entityId;
    final local = await (_db.select(
      _db.localWorkoutSessions,
    )..where((row) => row.id.equals(sessionId))).getSingleOrNull();
    if (local == null) {
      // Plus rien à défendre en local : l'opération n'a plus d'objet.
      _logger.warning('Conflit sur une séance absente en local : $sessionId');
      return SyncConflictVerdict.rejected;
    }

    final RemoteWorkoutSession remote;
    try {
      remote = await _remote.detail(sessionId);
    } on ServerException catch (exception) {
      if (exception.statusCode == 404) {
        return SyncConflictVerdict.rejected;
      }
      _logger.warning('Version serveur illisible', error: exception);
      return SyncConflictVerdict.retryLater;
    } on AppException catch (exception) {
      // Hors ligne, session à renouveler… : le prochain drainage rejouera
      // la clôture, le 409 reviendra, et on tranchera à ce moment-là.
      _logger.warning('Version serveur inaccessible', error: exception);
      return SyncConflictVerdict.retryLater;
    }

    if (remote.status == local.status) {
      // Même issue des deux côtés : rien à arbitrer. La version serveur fait
      // foi (dates de fin, durée), elle remplace la copie locale.
      await _downloader.write(remote);
      return SyncConflictVerdict.adopted;
    }
    if (remote.status == WorkoutStatus.inProgress.apiValue) {
      // Le serveur ne la voit plus close : le rejeu de la clôture passera.
      return SyncConflictVerdict.retryLater;
    }
    _logger.info(
      'Séance $sessionId close ${remote.status} sur le serveur, '
      '${local.status} ici : arbitrage demandé',
    );
    return SyncConflictVerdict.conflict;
  }
}

final workoutCloseConflictResolverProvider = Provider<SyncConflictResolver>((
  ref,
) {
  return WorkoutCloseConflictResolver(
    database: ref.watch(appDatabaseProvider),
    remote: ref.watch(workoutSessionRemoteDataSourceProvider),
  );
});
