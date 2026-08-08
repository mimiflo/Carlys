/// Sérialisation des modèles de séance — parsing manuel du JSON de l'API,
/// conforme à `packages/api-contracts/src/workout-templates.ts`.
library;

import '../../../workout_session/domain/entities/workout.dart';
import '../../domain/entities/workout_template.dart';

/// Corps de `PUT /api/v1/workout-templates/{id}` — l'**état complet** visé.
///
/// Deux règles du contrat sont matérialisées ici :
///  - **les positions ne sont jamais transmises** : l'ordre des tableaux fait
///    foi, le serveur écrit `position = index`. Un client ne peut donc
///    produire ni trou ni doublon de position ;
///  - **tous les identifiants sont ceux de l'appareil**, conservés tels quels :
///    c'est ce qui rend le rejeu de l'opération strictement identique.
Map<String, dynamic> templatePutBody(WorkoutTemplateDetail template) {
  return <String, dynamic>{
    'name': template.name,
    'notes': template.notes,
    'estimatedDurationMinutes': template.info.estimatedDurationMinutes,
    'exercises': [
      for (final exercise in template.exercises)
        <String, dynamic>{
          'id': exercise.id,
          'exerciseId': exercise.exerciseId,
          'exerciseName': exercise.exerciseName,
          'notes': exercise.notes,
          'sets': [
            for (final set in exercise.sets)
              <String, dynamic>{
                'id': set.id,
                'kind': set.kind.apiValue,
                'targetReps': set.targetReps,
                'targetWeightKg': set.targetWeightKg,
                'restSeconds': set.restSeconds,
              },
          ],
        },
    ],
  };
}

/// `WorkoutTemplateSummary` (élément de `GET /workout-templates`).
///
/// [syncState] n'existe pas côté serveur : ce qui vient du serveur est, par
/// construction, déjà synchronisé.
WorkoutTemplateInfo templateInfoFromJson(Map<String, dynamic> json) {
  return WorkoutTemplateInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    exercisesCount: (json['exercisesCount'] as num?)?.toInt() ?? 0,
    plannedSetsCount: (json['plannedSetsCount'] as num?)?.toInt() ?? 0,
    estimatedDurationMinutes:
        (json['estimatedDurationMinutes'] as num?)?.toInt(),
    previewExerciseNames:
        (json['previewExerciseNames'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
    lastUsedAt: _utcOrNull(json['lastUsedAt'] as String?),
    updatedAt:
        _utcOrNull(json['updatedAt'] as String?) ?? DateTime.now().toUtc(),
    syncState: LocalSyncState.synced,
  );
}

/// `WorkoutTemplateDetail` (`GET /workout-templates/{id}`).
WorkoutTemplateDetail templateDetailFromJson(Map<String, dynamic> json) {
  return WorkoutTemplateDetail(
    info: templateInfoFromJson(json),
    notes: json['notes'] as String?,
    exercises: [
      for (final exercise in (json['exercises'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>())
        TemplateExerciseEntry(
          id: exercise['id'] as String,
          exerciseId: exercise['exerciseId'] as String?,
          exerciseName: exercise['exerciseName'] as String,
          position: (exercise['position'] as num?)?.toInt() ?? 0,
          notes: exercise['notes'] as String?,
          sets: [
            for (final set in (exercise['sets'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>())
              PlannedSet(
                id: set['id'] as String,
                position: (set['position'] as num?)?.toInt() ?? 0,
                kind: SetKind.fromApi(set['kind'] as String? ?? 'NORMAL'),
                targetReps: (set['targetReps'] as num?)?.toInt(),
                targetWeightKg: (set['targetWeightKg'] as num?)?.toDouble(),
                restSeconds: (set['restSeconds'] as num?)?.toInt(),
              ),
          ],
        ),
    ],
  );
}

/// Les dates de l'API sont en UTC (ISO 8601) ; l'affichage est localisé plus
/// haut, jamais ici.
DateTime? _utcOrNull(String? value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value).toUtc();
}
