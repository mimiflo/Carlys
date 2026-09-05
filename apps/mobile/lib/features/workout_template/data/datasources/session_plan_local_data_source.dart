import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../domain/entities/session_plan.dart';

/// Accès Drift du **plan de la séance en cours**.
///
/// Séparé de l'accès aux modèles parce que c'est un autre cycle de vie — le
/// plan naît au lancement d'une séance et meurt à sa clôture, alors qu'un
/// modèle vit indéfiniment.
///
/// Le plan voyage vers le serveur, mais jamais tout seul : il part en bloc
/// avec `session.create`, ses appariements suivent la série qui les honore, et
/// seuls les « passer » ont leur propre opération. `syncStatus` retrace cet
/// acquittement, ce qui permet au rapatriement de savoir quand s'abstenir.
///
/// Comme pour les modèles, aucune méthode n'ouvre de transaction : le
/// repository décide de la frontière transactionnelle.
class SessionPlanLocalDataSource {
  const SessionPlanLocalDataSource(this._db);

  final AppDatabase _db;

  Stream<SessionPlan?> watchPlan(String sessionId) =>
      _planQuery(sessionId).watch().map(_toPlan);

  Future<SessionPlan?> plan(String sessionId) async =>
      _toPlan(await _planQuery(sessionId).get());

  JoinedSelectStatement<HasResultSet, dynamic> _planQuery(String sessionId) {
    return _db.select(_db.localWorkoutSessions).join([
      leftOuterJoin(
        _db.localSessionPlanItems,
        _db.localSessionPlanItems.sessionId.equalsExp(
          _db.localWorkoutSessions.id,
        ),
      ),
    ])..where(_db.localWorkoutSessions.id.equals(sessionId));
  }

  SessionPlan? _toPlan(List<TypedResult> rows) {
    if (rows.isEmpty) {
      return null;
    }
    final session = rows.first.readTable(_db.localWorkoutSessions);
    final items =
        rows
            .map((row) => row.readTableOrNull(_db.localSessionPlanItems))
            .whereType<LocalSessionPlanItem>()
            .map(mapPlanItem)
            .toList()
          ..sort((a, b) {
            final byExercise = a.exercisePosition.compareTo(b.exercisePosition);
            return byExercise != 0
                ? byExercise
                : a.setPosition.compareTo(b.setPosition);
          });

    // Séance libre : pas de plan, l'écran de séance garde son comportement.
    if (items.isEmpty) {
      return null;
    }
    return SessionPlan(
      sessionId: session.id,
      templateName: session.templateName ?? session.name ?? '',
      items: items,
    );
  }

  static SessionPlanItem mapPlanItem(LocalSessionPlanItem row) =>
      SessionPlanItem(
        id: row.id,
        sessionId: row.sessionId,
        exercisePosition: row.exercisePosition,
        exerciseId: row.exerciseId,
        exerciseName: row.exerciseName,
        setPosition: row.setPosition,
        kind: SetKind.fromApi(row.kind),
        targetReps: row.targetReps,
        targetWeightKg: row.targetWeightKg,
        restSeconds: row.restSeconds,
        doneSetId: row.doneSetId,
        skipped: row.skipped,
      );

  /// Matérialise le plan : le modèle est APLATI, une ligne par série prévue.
  Future<void> insertPlanItems(List<LocalSessionPlanItemsCompanion> items) {
    return _db.batch(
      (batch) => batch.insertAll(_db.localSessionPlanItems, items),
    );
  }

  Future<LocalSessionPlanItem?> itemOf(String planItemId) {
    return (_db.select(
      _db.localSessionPlanItems,
    )..where((item) => item.id.equals(planItemId))).getSingleOrNull();
  }

  /// Prévisions encore ouvertes d'un exercice : ni honorées, ni déjà passées.
  Future<List<String>> pendingItemIdsOf({
    required String sessionId,
    required int exercisePosition,
  }) async {
    final rows =
        await (_db.select(_db.localSessionPlanItems)..where(
              (item) =>
                  item.sessionId.equals(sessionId) &
                  item.exercisePosition.equals(exercisePosition) &
                  item.doneSetId.isNull() &
                  item.skipped.equals(false),
            ))
            .get();
    return rows.map((row) => row.id).toList();
  }

  /// L'appariement repart avec la série : l'item redevient donc `pending`
  /// jusqu'à ce que cette série soit acquittée.
  Future<void> fulfillItem({
    required String planItemId,
    required String setId,
  }) {
    return (_db.update(
      _db.localSessionPlanItems,
    )..where((item) => item.id.equals(planItemId))).write(
      LocalSessionPlanItemsCompanion(
        doneSetId: Value(setId),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> markSkipped(List<String> planItemIds) {
    return (_db.update(
      _db.localSessionPlanItems,
    )..where((item) => item.id.isIn(planItemIds))).write(
      const LocalSessionPlanItemsCompanion(
        skipped: Value(true),
        syncStatus: Value('pending'),
      ),
    );
  }

  Future<void> markStatus(List<String> planItemIds, String syncStatus) {
    return (_db.update(_db.localSessionPlanItems)
          ..where((item) => item.id.isIn(planItemIds)))
        .write(LocalSessionPlanItemsCompanion(syncStatus: Value(syncStatus)));
  }

  /// Acquitte tout le plan d'une séance — utilisé quand `session.create`,
  /// qui le transporte en bloc, aboutit.
  Future<void> markSessionStatus(String sessionId, String syncStatus) {
    return (_db.update(_db.localSessionPlanItems)
          ..where((item) => item.sessionId.equals(sessionId)))
        .write(LocalSessionPlanItemsCompanion(syncStatus: Value(syncStatus)));
  }

  /// Vrai si une modification locale du plan n'a pas encore été acquittée.
  Future<bool> hasUnacknowledgedItems(String sessionId) async {
    final rows =
        await (_db.select(_db.localSessionPlanItems)
              ..where(
                (item) =>
                    item.sessionId.equals(sessionId) &
                    item.syncStatus.isNotValue('synced'),
              )
              ..limit(1))
            .get();
    return rows.isNotEmpty;
  }

  /// Réécrit intégralement le plan rapatrié du serveur.
  Future<void> replacePlan(
    String sessionId,
    List<LocalSessionPlanItemsCompanion> items,
  ) async {
    await purgePlan(sessionId);
    await _db.batch(
      (batch) => batch.insertAll(_db.localSessionPlanItems, items),
    );
  }

  Future<void> purgePlan(String sessionId) {
    return (_db.delete(
      _db.localSessionPlanItems,
    )..where((item) => item.sessionId.equals(sessionId))).go();
  }
}
