import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../domain/entities/workout_template.dart';
import 'session_plan_local_data_source.dart';

/// Accès Drift des **modèles de séance** (le plan d'une séance en cours vit
/// dans [SessionPlanLocalDataSource]).
///
/// Toutes les méthodes d'écriture sont **composables dans une transaction**
/// (elles n'en ouvrent aucune) : c'est le repository qui décide de la frontière
/// transactionnelle, parce que lui seul sait ce qui doit être atomique avec la
/// mise en file de synchronisation.
class WorkoutTemplateLocalDataSource {
  const WorkoutTemplateLocalDataSource(this._db);

  final AppDatabase _db;

  // ── Lectures ─────────────────────────────────────────────────────────────

  Stream<List<WorkoutTemplateDetail>> watchAll() =>
      _contentQuery().watch().map(_groupTemplates);

  Future<WorkoutTemplateDetail?> detail(String templateId) async {
    final rows =
        await (_contentQuery()
              ..where(_db.localWorkoutTemplates.id.equals(templateId)))
            .get();
    final templates = _groupTemplates(rows);
    return templates.isEmpty ? null : templates.first;
  }

  JoinedSelectStatement<HasResultSet, dynamic> _contentQuery() {
    return _db.select(_db.localWorkoutTemplates).join([
      leftOuterJoin(
        _db.localTemplateExercises,
        _db.localTemplateExercises.templateId.equalsExp(
          _db.localWorkoutTemplates.id,
        ),
      ),
      leftOuterJoin(
        _db.localTemplateSets,
        _db.localTemplateSets.templateExerciseId.equalsExp(
          _db.localTemplateExercises.id,
        ),
      ),
    ])..where(_db.localWorkoutTemplates.deleted.equals(false));
  }

  /// Reconstitue les modèles depuis le produit cartésien du join.
  List<WorkoutTemplateDetail> _groupTemplates(List<TypedResult> rows) {
    final templates = <String, LocalWorkoutTemplate>{};
    final exercises = <String, Map<String, LocalTemplateExercise>>{};
    final sets = <String, Map<String, LocalTemplateSet>>{};

    for (final row in rows) {
      final template = row.readTable(_db.localWorkoutTemplates);
      templates[template.id] = template;
      final exercise = row.readTableOrNull(_db.localTemplateExercises);
      if (exercise == null) {
        continue;
      }
      (exercises[template.id] ??= {})[exercise.id] = exercise;
      final set = row.readTableOrNull(_db.localTemplateSets);
      if (set != null) {
        (sets[exercise.id] ??= {})[set.id] = set;
      }
    }

    final details =
        templates.values.map((template) {
            final lines = (exercises[template.id]?.values.toList() ?? [])
              ..sort((a, b) => a.position.compareTo(b.position));
            final entries = [
              for (final line in lines)
                TemplateExerciseEntry(
                  id: line.id,
                  exerciseId: line.exerciseId,
                  exerciseName: line.exerciseName,
                  position: line.position,
                  notes: line.notes,
                  sets:
                      ((sets[line.id]?.values.toList() ?? [])
                            ..sort((a, b) => a.position.compareTo(b.position)))
                          .map(_mapPlannedSet)
                          .toList(),
                ),
            ];
            return WorkoutTemplateDetail(
              info: _mapInfo(template, entries),
              notes: template.notes,
              exercises: entries,
            );
          }).toList()
          // Le modèle qu'on vient de retoucher remonte en tête, comme côté API.
          ..sort((a, b) => b.info.updatedAt.compareTo(a.info.updatedAt));
    return details;
  }

  PlannedSet _mapPlannedSet(LocalTemplateSet row) => PlannedSet(
    id: row.id,
    position: row.position,
    kind: SetKind.fromApi(row.kind),
    targetReps: row.targetReps,
    targetWeightKg: row.targetWeightKg,
    restSeconds: row.restSeconds,
  );

  WorkoutTemplateInfo _mapInfo(
    LocalWorkoutTemplate row,
    List<TemplateExerciseEntry> exercises,
  ) {
    return WorkoutTemplateInfo(
      id: row.id,
      name: row.name,
      exercisesCount: exercises.length,
      plannedSetsCount: exercises.fold(
        0,
        (total, exercise) => total + exercise.sets.length,
      ),
      estimatedDurationMinutes: row.estimatedDurationMinutes,
      previewExerciseNames: exercises
          .take(3)
          .map((exercise) => exercise.exerciseName)
          .toList(growable: false),
      lastUsedAt: row.lastUsedAt,
      updatedAt: row.updatedAt,
      syncState: LocalSyncState.fromDb(row.syncStatus),
    );
  }

  // ── Écritures du contenu d'un modèle ─────────────────────────────────────

  /// Remplace **physiquement** le contenu du modèle, en miroir exact du `PUT`
  /// serveur : le contenu d'un modèle n'est pas de l'historique, il n'est
  /// référencé par rien, le conserver n'aurait aucun usage.
  Future<void> replaceContent(WorkoutTemplateDetail template) async {
    final existing = await (_db.select(
      _db.localTemplateExercises,
    )..where((line) => line.templateId.equals(template.id))).get();
    final exerciseIds = existing.map((line) => line.id).toList();
    if (exerciseIds.isNotEmpty) {
      await (_db.delete(
        _db.localTemplateSets,
      )..where((set) => set.templateExerciseId.isIn(exerciseIds))).go();
    }
    await (_db.delete(
      _db.localTemplateExercises,
    )..where((line) => line.templateId.equals(template.id))).go();

    for (final exercise in template.exercises) {
      await _db
          .into(_db.localTemplateExercises)
          .insert(
            LocalTemplateExercisesCompanion.insert(
              id: exercise.id,
              templateId: template.id,
              exerciseId: Value(exercise.exerciseId),
              exerciseName: exercise.exerciseName,
              position: exercise.position,
              notes: Value(exercise.notes),
            ),
          );
      for (final set in exercise.sets) {
        await _db
            .into(_db.localTemplateSets)
            .insert(
              LocalTemplateSetsCompanion.insert(
                id: set.id,
                templateExerciseId: exercise.id,
                position: set.position,
                kind: Value(set.kind.apiValue),
                targetReps: Value(set.targetReps),
                targetWeightKg: Value(set.targetWeightKg),
                restSeconds: Value(set.restSeconds),
              ),
            );
      }
    }
  }

  /// Écrit l'en-tête du modèle. [lastUsedAt] est un miroir de la valeur
  /// serveur : il n'est jamais remis à `null` par un enregistrement.
  Future<void> upsertHeader({
    required WorkoutTemplateDetail template,
    required DateTime updatedAt,
    required String syncStatus,
    DateTime? lastUsedAt,
  }) {
    return _db
        .into(_db.localWorkoutTemplates)
        .insertOnConflictUpdate(
          LocalWorkoutTemplatesCompanion.insert(
            id: template.id,
            name: template.name,
            notes: Value(template.notes),
            estimatedDurationMinutes: Value(
              template.info.estimatedDurationMinutes,
            ),
            lastUsedAt: Value(lastUsedAt),
            updatedAt: updatedAt,
            deleted: const Value(false),
            syncStatus: Value(syncStatus),
          ),
        );
  }

  Future<LocalWorkoutTemplate?> headerOf(String templateId) {
    return (_db.select(
      _db.localWorkoutTemplates,
    )..where((template) => template.id.equals(templateId))).getSingleOrNull();
  }

  /// Pose le tombstone : la ligne reste jusqu'à l'acquittement serveur, mais
  /// le modèle disparaît immédiatement de toutes les lectures.
  Future<void> markDeleted(String templateId) {
    return (_db.update(
      _db.localWorkoutTemplates,
    )..where((template) => template.id.equals(templateId))).write(
      const LocalWorkoutTemplatesCompanion(
        deleted: Value(true),
        syncStatus: Value('pending'),
      ),
    );
  }

  Future<void> touchLastUsedAt(String templateId, DateTime lastUsedAt) {
    return (_db.update(_db.localWorkoutTemplates)
          ..where((template) => template.id.equals(templateId)))
        .write(LocalWorkoutTemplatesCompanion(lastUsedAt: Value(lastUsedAt)));
  }
}
