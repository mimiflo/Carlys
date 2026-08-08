/// Validation et normalisation d'une saisie de modèle — logique métier pure,
/// sans base ni réseau, donc testable seule.
library;

import '../../../workout_session/domain/entities/workout.dart';
import '../entities/workout_template.dart';

/// Transforme une [SaveTemplateInput] en [WorkoutTemplateDetail] prêt à être
/// écrit : noms trimés, identifiants complétés, **positions dérivées de
/// l'ordre des listes**.
///
/// Les positions ne sont jamais fournies par l'appelant — ni ici, ni sur le
/// réseau : ainsi un client ne peut produire ni trou ni doublon.
///
/// Lève [InvalidTemplateException] dès qu'une borne partagée avec l'API est
/// dépassée. Refuser ici, c'est éviter un refus serveur des heures plus tard,
/// qui transformerait le modèle composé hors ligne en travail perdu.
WorkoutTemplateDetail normalizeTemplateInput({
  required SaveTemplateInput input,
  required String Function() newId,
  required DateTime updatedAt,
  DateTime? lastUsedAt,
  LocalSyncState syncState = LocalSyncState.pending,
}) {
  final name = input.name.trim();
  if (name.isEmpty) {
    throw const InvalidTemplateException('Le nom du modèle est obligatoire.');
  }
  if (name.length > WorkoutTemplateLimits.nameMax) {
    throw const InvalidTemplateException(
      'Le nom du modèle est trop long (120 caractères maximum).',
    );
  }

  final notes = _trimToNull(input.notes);
  if (notes != null && notes.length > WorkoutTemplateLimits.notesMax) {
    throw const InvalidTemplateException('Les notes sont trop longues.');
  }

  final duration = input.estimatedDurationMinutes;
  if (duration != null &&
      (duration < 1 ||
          duration > WorkoutTemplateLimits.estimatedDurationMinutesMax)) {
    throw const InvalidTemplateException(
      'La durée estimée doit être comprise entre 1 et 1 440 minutes.',
    );
  }

  if (input.exercises.isEmpty) {
    throw const InvalidTemplateException(
      'Un modèle contient au moins un exercice.',
    );
  }
  if (input.exercises.length > WorkoutTemplateLimits.exercisesMax) {
    throw const InvalidTemplateException(
      'Un modèle contient au plus 30 exercices.',
    );
  }

  final exercises = <TemplateExerciseEntry>[];
  for (final (position, exercise) in input.exercises.indexed) {
    exercises.add(
      _normalizeExercise(exercise: exercise, position: position, newId: newId),
    );
  }

  final templateId = input.id ?? newId();
  return WorkoutTemplateDetail(
    info: WorkoutTemplateInfo(
      id: templateId,
      name: name,
      exercisesCount: exercises.length,
      plannedSetsCount:
          exercises.fold(0, (total, exercise) => total + exercise.sets.length),
      estimatedDurationMinutes: duration,
      previewExerciseNames: exercises
          .take(3)
          .map((exercise) => exercise.exerciseName)
          .toList(growable: false),
      lastUsedAt: lastUsedAt,
      updatedAt: updatedAt,
      syncState: syncState,
    ),
    notes: notes,
    exercises: exercises,
  );
}

TemplateExerciseEntry _normalizeExercise({
  required TemplateExerciseInput exercise,
  required int position,
  required String Function() newId,
}) {
  final exerciseName = exercise.exerciseName.trim();
  if (exerciseName.isEmpty) {
    throw const InvalidTemplateException(
      'Chaque exercice du modèle doit être nommé.',
    );
  }
  if (exercise.sets.isEmpty) {
    throw const InvalidTemplateException(
      'Chaque exercice du modèle prévoit au moins une série.',
    );
  }
  if (exercise.sets.length > WorkoutTemplateLimits.setsPerExerciseMax) {
    throw const InvalidTemplateException(
      'Un exercice prévoit au plus 20 séries.',
    );
  }

  return TemplateExerciseEntry(
    id: exercise.id ?? newId(),
    exerciseId: exercise.exerciseId,
    exerciseName: exerciseName,
    position: position,
    notes: _trimToNull(exercise.notes),
    sets: [
      for (final (setPosition, set) in exercise.sets.indexed)
        _normalizeSet(set: set, position: setPosition, newId: newId),
    ],
  );
}

PlannedSet _normalizeSet({
  required PlannedSetInput set,
  required int position,
  required String Function() newId,
}) {
  final reps = set.targetReps;
  if (reps != null && (reps < 0 || reps > WorkoutTemplateLimits.repsMax)) {
    throw const InvalidTemplateException(
      'Les répétitions prévues doivent être comprises entre 0 et 1 000.',
    );
  }
  final weight = set.targetWeightKg;
  if (weight != null &&
      (weight < 0 || weight > WorkoutTemplateLimits.weightKgMax)) {
    throw const InvalidTemplateException(
      'La charge prévue doit être comprise entre 0 et 1 000 kg.',
    );
  }
  final rest = set.restSeconds;
  if (rest != null &&
      (rest < 0 || rest > WorkoutTemplateLimits.restSecondsMax)) {
    throw const InvalidTemplateException(
      'Le repos prévu doit être compris entre 0 et 3 600 secondes.',
    );
  }

  return PlannedSet(
    id: set.id ?? newId(),
    position: position,
    kind: set.kind,
    targetReps: reps,
    targetWeightKg: weight,
    restSeconds: rest,
  );
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
