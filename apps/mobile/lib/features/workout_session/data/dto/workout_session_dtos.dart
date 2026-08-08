/// Lecture des enveloppes `WorkoutSessionSummary` / `WorkoutSessionDetail`,
/// conformes à `packages/api-contracts/src/workouts.ts`.
///
/// Ces objets ne servent QU'AU RAPATRIEMENT : ils traversent la couche data
/// pour être écrits dans Drift, jamais pour être affichés — les écrans lisent
/// toujours le local.
library;

/// Séance renvoyée par le serveur, avec ses séries et son plan.
class RemoteWorkoutSession {
  const RemoteWorkoutSession({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.sets,
    required this.plan,
    this.name,
    this.notes,
    this.endedAt,
    this.durationSeconds,
    this.templateId,
    this.templateName,
  });

  final String id;
  final String? name;
  final String? notes;

  /// IN_PROGRESS | COMPLETED | ABANDONED (valeurs API, écrites telles quelles).
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String? templateId;
  final String? templateName;
  final List<RemoteWorkoutSet> sets;
  final List<RemoteSessionPlanItem> plan;
}

class RemoteWorkoutSet {
  const RemoteWorkoutSet({
    required this.id,
    required this.exerciseName,
    required this.position,
    required this.kind,
    required this.completedAt,
    this.exerciseId,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.restSeconds,
    this.rpe,
    this.plannedReps,
    this.plannedWeightKg,
  });

  final String id;
  final String? exerciseId;
  final String exerciseName;
  final int position;
  final String kind;
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final int? restSeconds;
  final int? rpe;
  final int? plannedReps;
  final double? plannedWeightKg;
  final DateTime completedAt;
}

class RemoteSessionPlanItem {
  const RemoteSessionPlanItem({
    required this.id,
    required this.exercisePosition,
    required this.exerciseName,
    required this.setPosition,
    required this.kind,
    required this.skipped,
    this.exerciseId,
    this.targetReps,
    this.targetWeightKg,
    this.restSeconds,
    this.doneSetId,
  });

  final String id;
  final int exercisePosition;
  final String? exerciseId;
  final String exerciseName;
  final int setPosition;
  final String kind;
  final int? targetReps;
  final double? targetWeightKg;
  final int? restSeconds;
  final String? doneSetId;
  final bool skipped;
}

/// Identifiant + date de début d'une séance listée : tout ce dont le
/// rapatriement a besoin avant de décider s'il télécharge le détail.
class RemoteWorkoutSessionRef {
  const RemoteWorkoutSessionRef({required this.id, required this.startedAt});

  final String id;
  final DateTime startedAt;
}

RemoteWorkoutSessionRef sessionRefFromJson(Map<String, dynamic> json) {
  return RemoteWorkoutSessionRef(
    id: json['id'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
  );
}

RemoteWorkoutSession sessionFromJson(Map<String, dynamic> json) {
  final endedAt = json['endedAt'] as String?;
  return RemoteWorkoutSession(
    id: json['id'] as String,
    name: json['name'] as String?,
    notes: json['notes'] as String?,
    status: json['status'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
    endedAt: endedAt == null ? null : DateTime.parse(endedAt).toUtc(),
    durationSeconds: json['durationSeconds'] as int?,
    templateId: json['templateId'] as String?,
    templateName: json['templateName'] as String?,
    sets: (json['sets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_setFromJson)
        .toList(),
    plan: (json['plan'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_planItemFromJson)
        .toList(),
  );
}

RemoteWorkoutSet _setFromJson(Map<String, dynamic> json) {
  return RemoteWorkoutSet(
    id: json['id'] as String,
    exerciseId: json['exerciseId'] as String?,
    exerciseName: json['exerciseName'] as String,
    position: json['position'] as int,
    kind: json['kind'] as String,
    reps: json['reps'] as int?,
    weightKg: _toDouble(json['weightKg']),
    durationSeconds: json['durationSeconds'] as int?,
    restSeconds: json['restSeconds'] as int?,
    rpe: json['rpe'] as int?,
    plannedReps: json['plannedReps'] as int?,
    plannedWeightKg: _toDouble(json['plannedWeightKg']),
    completedAt: DateTime.parse(json['completedAt'] as String).toUtc(),
  );
}

RemoteSessionPlanItem _planItemFromJson(Map<String, dynamic> json) {
  return RemoteSessionPlanItem(
    id: json['id'] as String,
    exercisePosition: json['exercisePosition'] as int,
    exerciseId: json['exerciseId'] as String?,
    exerciseName: json['exerciseName'] as String,
    setPosition: json['setPosition'] as int,
    kind: json['kind'] as String,
    targetReps: json['targetReps'] as int?,
    targetWeightKg: _toDouble(json['targetWeightKg']),
    restSeconds: json['restSeconds'] as int?,
    doneSetId: json['doneSetId'] as String?,
    skipped: json['skipped'] as bool? ?? false,
  );
}

/// Le JSON rend un entier quand la décimale est ronde (`60` et non `60.0`).
double? _toDouble(Object? value) => (value as num?)?.toDouble();
