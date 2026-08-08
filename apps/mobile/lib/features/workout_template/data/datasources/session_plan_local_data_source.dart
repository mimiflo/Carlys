import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../domain/entities/session_plan.dart';

/// Accès Drift du **plan de la séance en cours**.
///
/// Table purement locale : rien de ce qui est ici ne part vers le serveur, qui
/// ne reçoit que des faits. Séparé de l'accès aux modèles parce que c'est un
/// autre cycle de vie — le plan naît au lancement d'une séance et meurt à sa
/// clôture, alors qu'un modèle vit indéfiniment.
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
        _db.localSessionPlanItems.sessionId
            .equalsExp(_db.localWorkoutSessions.id),
      ),
    ])
      ..where(_db.localWorkoutSessions.id.equals(sessionId));
  }

  SessionPlan? _toPlan(List<TypedResult> rows) {
    if (rows.isEmpty) {
      return null;
    }
    final session = rows.first.readTable(_db.localWorkoutSessions);
    final items = rows
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

  Future<void> fulfillItem({
    required String planItemId,
    required String setId,
  }) {
    return (_db.update(_db.localSessionPlanItems)
          ..where((item) => item.id.equals(planItemId)))
        .write(LocalSessionPlanItemsCompanion(doneSetId: Value(setId)));
  }

  Future<void> skipItem(String planItemId) {
    return (_db.update(_db.localSessionPlanItems)
          ..where((item) => item.id.equals(planItemId)))
        .write(const LocalSessionPlanItemsCompanion(skipped: Value(true)));
  }

  /// Passe les séries **restantes** de l'exercice : celles déjà faites gardent
  /// leur statut, une série réalisée est un fait acquis.
  Future<void> skipExercise({
    required String sessionId,
    required int exercisePosition,
  }) {
    return (_db.update(_db.localSessionPlanItems)
          ..where(
            (item) =>
                item.sessionId.equals(sessionId) &
                item.exercisePosition.equals(exercisePosition) &
                item.doneSetId.isNull(),
          ))
        .write(const LocalSessionPlanItemsCompanion(skipped: Value(true)));
  }

  Future<void> purgePlan(String sessionId) {
    return (_db.delete(_db.localSessionPlanItems)
          ..where((item) => item.sessionId.equals(sessionId)))
        .go();
  }
}
