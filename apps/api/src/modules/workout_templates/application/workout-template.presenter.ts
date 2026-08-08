import {
  type WorkoutTemplateDetail,
  type WorkoutTemplateExercise as WorkoutTemplateExerciseContract,
  type WorkoutTemplateSet as WorkoutTemplateSetContract,
  type WorkoutTemplateSummary,
} from '@carlys/api-contracts';
import { type WorkoutTemplateExercise, type WorkoutTemplateSet } from '@prisma/client';
import {
  type TemplateWithContent,
  type TemplateWithCounts,
} from '../infrastructure/workout-templates.repository';

/** Sous-titre de la carte : les premiers exercices, dans l'ordre. */
const PREVIEW_EXERCISE_NAMES_MAX = 3;

function presentPlannedSet(set: WorkoutTemplateSet): WorkoutTemplateSetContract {
  return {
    id: set.id,
    position: set.position,
    kind: set.kind,
    targetReps: set.targetReps,
    targetWeightKg: set.targetWeightKg === null ? null : Number(set.targetWeightKg),
    restSeconds: set.restSeconds,
  };
}

function presentTemplateExercise(
  exercise: WorkoutTemplateExercise & { sets: WorkoutTemplateSet[] },
): WorkoutTemplateExerciseContract {
  return {
    id: exercise.id,
    exerciseId: exercise.exerciseId,
    exerciseName: exercise.exerciseName,
    position: exercise.position,
    notes: exercise.notes,
    sets: exercise.sets.map(presentPlannedSet),
  };
}

/** Carte de la liste : compte les séries prévues sans jamais les charger. */
export function presentTemplateSummary(template: TemplateWithCounts): WorkoutTemplateSummary {
  return {
    id: template.id,
    name: template.name,
    exercisesCount: template.exercises.length,
    plannedSetsCount: template.exercises.reduce((total, entry) => total + entry._count.sets, 0),
    estimatedDurationMinutes: template.estimatedDurationMinutes,
    previewExerciseNames: template.exercises
      .slice(0, PREVIEW_EXERCISE_NAMES_MAX)
      .map((entry) => entry.exerciseName),
    lastUsedAt: template.lastUsedAt?.toISOString() ?? null,
    updatedAt: template.updatedAt.toISOString(),
  };
}

export function presentTemplateDetail(template: TemplateWithContent): WorkoutTemplateDetail {
  return {
    ...presentTemplateSummary({
      ...template,
      exercises: template.exercises.map((exercise) => ({
        exerciseName: exercise.exerciseName,
        _count: { sets: exercise.sets.length },
      })),
    }),
    notes: template.notes,
    createdAt: template.createdAt.toISOString(),
    exercises: template.exercises.map(presentTemplateExercise),
  };
}
