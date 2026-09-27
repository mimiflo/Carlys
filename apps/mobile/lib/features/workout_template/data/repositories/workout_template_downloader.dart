import '../../../../core/database/app_database.dart';
import '../../domain/entities/workout_template.dart';
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
        if (local != null && _unchanged(local, summary)) {
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

  /// Le modèle local, déjà synchronisé, est-il celui que le serveur décrit ?
  ///
  /// Chaque lancement à froid retéléchargeait et réécrivait TOUS les
  /// modèles, identiques ou non. Le serveur date chaque écriture du modèle
  /// (`updatedAt`, remis à jour par tout enregistrement de son contenu comme
  /// par un lancement, qui pose `lastUsedAt`) : les mêmes dates, c'est le
  /// même modèle.
  ///
  /// À la SECONDE : Drift range un `DateTime` en secondes Unix et le relit
  /// en heure locale, quand le serveur sert des millisecondes en UTC. `==`
  /// ne serait donc jamais vrai (il compare aussi le fuseau). Seule limite :
  /// deux enregistrements du même modèle dans la même seconde, depuis un
  /// autre appareil, entre lesquels celui-ci aurait lu.
  static bool _unchanged(
    LocalWorkoutTemplate local,
    WorkoutTemplateInfo summary,
  ) =>
      _sameSecond(local.updatedAt, summary.updatedAt) &&
      _sameSecond(local.lastUsedAt, summary.lastUsedAt);

  static bool _sameSecond(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.millisecondsSinceEpoch ~/ 1000 == b.millisecondsSinceEpoch ~/ 1000;
  }
}
