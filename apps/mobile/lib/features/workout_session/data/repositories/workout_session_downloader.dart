import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../workout_template/data/datasources/session_plan_local_data_source.dart';
import '../../domain/entities/workout.dart';
import '../datasources/workout_session_remote_data_source.dart';
import '../dto/workout_session_dtos.dart';

/// Rapatriement des séances depuis le serveur vers la base locale.
///
/// C'est le pendant en LECTURE de la file de synchronisation : les écritures
/// partent par `SyncEngine`, jamais par ici. Il sert au changement d'appareil
/// et à la réinstallation — sans lui, un téléphone neuf n'a rien à afficher,
/// et une séance commencée ailleurs est irrécupérable.
///
/// Il écrit aussi le PLAN, qui vit dans une table de la fonctionnalité
/// « modèles ». Ce franchissement est assumé et symétrique de celui qui existe
/// déjà en sens inverse (`WorkoutTemplateRepositoryImpl` réutilise
/// `WorkoutSessionWriter`) : dupliquer l'écriture du plan serait pire.
class WorkoutSessionDownloader {
  WorkoutSessionDownloader({
    required AppDatabase database,
    required WorkoutSessionRemoteDataSource remote,
  })  : _db = database,
        _remote = remote,
        _plans = SessionPlanLocalDataSource(database);

  static const _logger = AppLogger('WorkoutSessionDownloader');

  /// Plafond de séances rapatriées, les plus récentes d'abord.
  ///
  /// Assez pour remplir l'historique, le calendrier et les statistiques d'un
  /// utilisateur régulier sur plusieurs mois, sans rejouer des années
  /// d'archives à chaque installation. Une séance en cours est forcément dans
  /// le lot : la liste est triée par date de début décroissante.
  static const restoredSessionsMax = 60;

  /// Taille de page demandée au serveur (borne partagée `MAX_PAGE_SIZE`).
  static const _pageSize = 50;

  static final _inProgress = WorkoutStatus.inProgress.apiValue;

  final AppDatabase _db;
  final WorkoutSessionRemoteDataSource _remote;
  final SessionPlanLocalDataSource _plans;

  /// Renvoie le nombre de séances effectivement réécrites en local.
  Future<int> run() async {
    final refs = await _collectRefs();
    var restored = 0;

    for (final ref in refs) {
      // Une saisie locale non acquittée gagne TOUJOURS : l'appareil ne perd
      // jamais ce qu'il a enregistré au profit d'un état serveur plus ancien.
      if (await _hasLocalChanges(ref.id)) {
        continue;
      }
      final detail = await _remote.detail(ref.id);
      if (await _wouldBreakSingleActiveRule(detail)) {
        continue;
      }
      await _write(detail);
      restored++;
    }
    return restored;
  }

  /// Le domaine impose **au plus une séance en cours**. Si l'appareil en a
  /// déjà une autre, la sienne gagne : importer la séance distante rendrait
  /// l'écran de séance et l'appariement au plan ambigus. Rien n'est perdu —
  /// elle reste sur le serveur et sera rapatriée quand celle-ci sera clôturée.
  Future<bool> _wouldBreakSingleActiveRule(RemoteWorkoutSession session) async {
    if (session.status != _inProgress) {
      return false;
    }
    final active = await (_db.select(_db.localWorkoutSessions)
          ..where(
            (row) =>
                row.status.equals(_inProgress) &
                row.id.equals(session.id).not(),
          )
          ..limit(1))
        .get();
    if (active.isEmpty) {
      return false;
    }
    _logger.info(
      'Séance distante ${session.id} non rapatriée : une autre séance est '
      'déjà en cours sur cet appareil',
    );
    return true;
  }

  /// Parcourt les pages jusqu'au plafond. Le dépassement est JOURNALISÉ :
  /// une troncature silencieuse se lirait comme un rapatriement complet.
  Future<List<RemoteWorkoutSessionRef>> _collectRefs() async {
    final refs = <RemoteWorkoutSessionRef>[];
    String? cursor;

    do {
      final page = await _remote.list(cursor: cursor, limit: _pageSize);
      refs.addAll(page.items);
      if (refs.length >= restoredSessionsMax) {
        if (page.hasMore || refs.length > restoredSessionsMax) {
          _logger.info(
            'Rapatriement borné aux $restoredSessionsMax séances les plus '
            'récentes ; les plus anciennes restent sur le serveur',
          );
        }
        return refs.take(restoredSessionsMax).toList();
      }
      cursor = page.hasMore ? page.nextCursor : null;
    } while (cursor != null);

    return refs;
  }

  Future<bool> _hasLocalChanges(String sessionId) async {
    final session = await (_db.select(_db.localWorkoutSessions)
          ..where((row) => row.id.equals(sessionId)))
        .getSingleOrNull();
    if (session == null) {
      return false; // inconnue en local : rien à protéger
    }
    if (session.syncStatus != 'synced') {
      return true;
    }
    final sets = await (_db.select(_db.localWorkoutSets)
          ..where(
            (row) =>
                row.sessionId.equals(sessionId) &
                row.syncStatus.isNotValue('synced'),
          )
          ..limit(1))
        .get();
    if (sets.isNotEmpty) {
      return true;
    }
    return _plans.hasUnacknowledgedItems(sessionId);
  }

  /// Une transaction par séance : une coupure au milieu laisse une base
  /// cohérente, simplement incomplète — le prochain appel reprendra.
  Future<void> _write(RemoteWorkoutSession session) {
    return _db.transaction(() async {
      await _db.into(_db.localWorkoutSessions).insertOnConflictUpdate(
            LocalWorkoutSessionsCompanion.insert(
              id: session.id,
              name: Value(session.name),
              notes: Value(session.notes),
              status: session.status,
              startedAt: session.startedAt,
              endedAt: Value(session.endedAt),
              durationSeconds: Value(session.durationSeconds),
              templateId: Value(session.templateId),
              templateName: Value(session.templateName),
              syncStatus: const Value('synced'),
            ),
          );

      // Le serveur ne sert que les séries vivantes : remplacer d'un bloc
      // reproduit donc exactement son état, suppressions comprises.
      await (_db.delete(_db.localWorkoutSets)
            ..where((row) => row.sessionId.equals(session.id)))
          .go();
      await _db.batch(
        (batch) => batch.insertAll(
          _db.localWorkoutSets,
          session.sets.map((set) => _setRow(session.id, set)),
        ),
      );

      await _plans.replacePlan(
        session.id,
        session.plan.map((item) => _planRow(session.id, item)).toList(),
      );
    });
  }

  LocalWorkoutSetsCompanion _setRow(String sessionId, RemoteWorkoutSet set) {
    return LocalWorkoutSetsCompanion.insert(
      id: set.id,
      sessionId: sessionId,
      exerciseId: Value(set.exerciseId),
      exerciseName: set.exerciseName,
      position: set.position,
      kind: Value(set.kind),
      reps: Value(set.reps),
      weightKg: Value(set.weightKg),
      durationSeconds: Value(set.durationSeconds),
      restSeconds: Value(set.restSeconds),
      rpe: Value(set.rpe),
      plannedReps: Value(set.plannedReps),
      plannedWeightKg: Value(set.plannedWeightKg),
      completedAt: set.completedAt,
      syncStatus: const Value('synced'),
    );
  }

  LocalSessionPlanItemsCompanion _planRow(
    String sessionId,
    RemoteSessionPlanItem item,
  ) {
    return LocalSessionPlanItemsCompanion.insert(
      id: item.id,
      sessionId: sessionId,
      exercisePosition: item.exercisePosition,
      exerciseId: Value(item.exerciseId),
      exerciseName: item.exerciseName,
      setPosition: item.setPosition,
      kind: Value(item.kind),
      targetReps: Value(item.targetReps),
      targetWeightKg: Value(item.targetWeightKg),
      restSeconds: Value(item.restSeconds),
      doneSetId: Value(item.doneSetId),
      skipped: Value(item.skipped),
      syncStatus: const Value('synced'),
    );
  }
}
