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

  /// Détails demandés ensemble, comme pour les séances
  /// (`WorkoutSessionDownloader`) : sur un téléphone neuf, chaque modèle
  /// attendait la réponse du précédent.
  static const _parallelDetails = 6;

  /// Parcourt toutes les pages (pagination par curseur) et écrit chaque modèle
  /// dans une transaction distincte : une coupure au milieu laisse une base
  /// cohérente, simplement incomplète — le prochain appel reprendra.
  ///
  /// Les détails se téléchargent par lots de [_parallelDetails] ; les
  /// écritures restent une à une, dans l'ordre de la liste.
  ///
  /// [shouldContinue], consulté avant chaque lot et chaque écriture, arrête
  /// la boucle dès qu'il rend faux (purge de compte en vol), comme pour les
  /// séances.
  Future<void> run({bool Function()? shouldContinue}) async {
    bool stopped() => shouldContinue != null && !shouldContinue();
    String? cursor;
    do {
      final page = await _remote.list(cursor: cursor);
      final items = page.items;
      for (var start = 0; start < items.length; start += _parallelDetails) {
        if (stopped()) return;
        // Relu lot par lot, juste avant le téléchargement : une saisie
        // locale ne peut croiser le rapatriement que le temps d'un lot,
        // comme pour les séances.
        final stale = [
          for (final summary in items.skip(start).take(_parallelDetails))
            if (await _needsDownload(summary)) summary.id,
        ];
        // Lancés ensemble, attendus dans l'ordre : un détail en échec
        // n'empêche pas d'écrire ceux qui le précèdent. `ignore` : un échec
        // laissé en vol ne remonte pas en erreur non traitée.
        final details = [for (final id in stale) _remote.detail(id)..ignore()];
        for (final pending in details) {
          if (stopped()) return;
          await _write(await pending);
        }
      }
      cursor = page.hasMore ? page.nextCursor : null;
    } while (cursor != null);
  }

  Future<bool> _needsDownload(WorkoutTemplateInfo summary) async {
    final local = await _local.headerOf(summary.id);
    // Une modification locale non acquittée gagne toujours : l'appareil ne
    // perd jamais sa propre saisie au profit d'un état serveur plus ancien.
    if (local != null && local.syncStatus != 'synced') return false;
    return local == null || !_unchanged(local, summary);
  }

  Future<void> _write(WorkoutTemplateDetail detail) {
    return _db.transaction(() async {
      // Relu ICI, dans la transaction : entre la vérification du lot et
      // l'arrivée du détail, l'utilisateur a pu supprimer ou retoucher le
      // modèle. `upsertHeader` réécrirait `deleted: false` et `synced` — un
      // modèle supprimé ressusciterait, pour toujours.
      final local = await _local.headerOf(detail.info.id);
      if (local != null && local.syncStatus != 'synced') return;
      await _local.upsertHeader(
        template: detail,
        updatedAt: detail.info.updatedAt,
        syncStatus: 'synced',
        lastUsedAt: detail.info.lastUsedAt,
        fromCoach: detail.info.fromCoach,
      );
      await _local.replaceContent(detail);
    });
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
      _sameSecond(local.lastUsedAt, summary.lastUsedAt) &&
      // Rangé avant que la catégorie existe : relu une fois pour la recevoir.
      local.fromCoach == summary.fromCoach;

  static bool _sameSecond(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.millisecondsSinceEpoch ~/ 1000 == b.millisecondsSinceEpoch ~/ 1000;
  }
}
