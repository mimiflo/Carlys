import { z } from 'zod';
import { workoutSetKindSchema } from './workouts';

/**
 * Contrats des modèles de séance (/api/v1/workout-templates).
 *
 * Un modèle de séance est un document PRESCRIPTIF réutilisable : ce que
 * l'utilisateur a PRÉVU de faire. La séance (`WorkoutSession`) reste le fait
 * constaté ; les deux ne se remplacent pas.
 *
 * Les identifiants — modèle, lignes d'exercice, séries prévues — sont des UUID
 * générés SUR L'APPAREIL : l'écriture unique (`PUT`) est naturellement
 * idempotente, le corps décrivant l'état final complet du modèle.
 */

/** Série prévue : des CIBLES, pas des mesures. Les trois sont facultatives. */
export const workoutTemplateSetSchema = z.object({
  id: z.string(),
  position: z.number(),
  kind: workoutSetKindSchema,
  targetReps: z.number().nullable(),
  targetWeightKg: z.number().nullable(),
  restSeconds: z.number().nullable(),
});
export type WorkoutTemplateSet = z.infer<typeof workoutTemplateSetSchema>;

/** Ligne d'exercice prescrite dans un modèle, à une position donnée. */
export const workoutTemplateExerciseSchema = z.object({
  id: z.string(),
  exerciseId: z.string().nullable(),
  /** Dénormalisé : le modèle survit aux évolutions du catalogue. */
  exerciseName: z.string(),
  position: z.number(),
  notes: z.string().nullable(),
  sets: z.array(workoutTemplateSetSchema),
});
export type WorkoutTemplateExercise = z.infer<typeof workoutTemplateExerciseSchema>;

export const workoutTemplateSummarySchema = z.object({
  id: z.string(),
  name: z.string(),
  exercisesCount: z.number(),
  plannedSetsCount: z.number(),
  estimatedDurationMinutes: z.number().nullable(),
  /** Trois premiers exercices, dans l'ordre — sous-titre de la carte. */
  previewExerciseNames: z.array(z.string()),
  lastUsedAt: z.string().nullable(),
  updatedAt: z.string(),
});
export type WorkoutTemplateSummary = z.infer<typeof workoutTemplateSummarySchema>;

export const workoutTemplateDetailSchema = workoutTemplateSummarySchema.extend({
  notes: z.string().nullable(),
  createdAt: z.string(),
  exercises: z.array(workoutTemplateExerciseSchema),
});
export type WorkoutTemplateDetail = z.infer<typeof workoutTemplateDetailSchema>;

/** Bornes propres aux modèles ; le reste vient de WORKOUT_LIMITS. */
export const WORKOUT_TEMPLATE_LIMITS = {
  exercisesMax: 30,
  setsPerExerciseMax: 20,
  estimatedDurationMinutesMax: 1_440,
} as const;
