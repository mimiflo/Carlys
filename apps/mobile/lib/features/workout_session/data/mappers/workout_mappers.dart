import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/workout.dart';

/// Traduction lignes Drift → entités du domaine.
///
/// Sorti du dépôt, qui dépassait sa limite de taille : la traduction est
/// une responsabilité à elle seule, sans état, et le dépôt garde ce qui le
/// définit — les lectures, les écritures et la mise en file.
class WorkoutRowMapper {
  const WorkoutRowMapper(this._db);

  final AppDatabase _db;

  /// Reconstitue les séances depuis le produit cartésien d'une jointure
  /// séance ⋈ séries.
  List<WorkoutWithSets> groupRows(List<TypedResult> rows) {
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
        session: mapSession(session),
        sets: sets.map(mapSet).toList(),
      );
    }).toList();
  }

  WorkoutInfo mapSession(LocalWorkoutSession row) => WorkoutInfo(
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

  WorkoutSetEntry mapSet(LocalWorkoutSet row) => WorkoutSetEntry(
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
