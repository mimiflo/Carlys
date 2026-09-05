import '../../../../core/database/app_database.dart';
import '../datasources/workout_template_local_data_source.dart';
import '../datasources/workout_template_remote_data_source.dart';

/// Rapatriement des modèles depuis le serveur vers la base locale.
///
/// Utile après une réinstallation ou un changement d'appareil : les modèles
/// vivent côté serveur, mais l'application les lit toujours en local.
///
/// C'est le **seul** sens de lecture réseau de la fonctionnalité : les
/// écritures passent par la file de synchronisation, jamais par ici.
class WorkoutTemplateDownloader {
  const WorkoutTemplateDownloader({
    required AppDatabase database,
    required this._local,
    required this._remote,
  }) : _db = database;

  final AppDatabase _db;
  final WorkoutTemplateLocalDataSource _local;
  final WorkoutTemplateRemoteDataSource _remote;

  /// Parcourt toutes les pages (pagination par curseur) et écrit chaque modèle
  /// dans une transaction distincte : une coupure au milieu laisse une base
  /// cohérente, simplement incomplète — le prochain appel reprendra.
  Future<void> run() async {
    String? cursor;
    do {
      final page = await _remote.list(cursor: cursor);
      for (final summary in page.items) {
        final local = await _local.headerOf(summary.id);
        // Une modification locale non acquittée gagne toujours : l'appareil ne
        // perd jamais sa propre saisie au profit d'un état serveur plus ancien.
        if (local != null && local.syncStatus != 'synced') {
          continue;
        }
        final detail = await _remote.detail(summary.id);
        await _db.transaction(() async {
          await _local.upsertHeader(
            template: detail,
            updatedAt: detail.info.updatedAt,
            syncStatus: 'synced',
            lastUsedAt: detail.info.lastUsedAt,
          );
          await _local.replaceContent(detail);
        });
      }
      cursor = page.hasMore ? page.nextCursor : null;
    } while (cursor != null);
  }
}
