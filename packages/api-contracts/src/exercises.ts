import { z } from 'zod';

/** Contrats du catalogue d'exercices (/api/v1/exercises, référentiels). */

export const exerciseDifficultySchema = z.enum(['BEGINNER', 'INTERMEDIATE', 'ADVANCED']);
export type ExerciseDifficulty = z.infer<typeof exerciseDifficultySchema>;

export const exerciseTypeSchema = z.enum(['STRENGTH', 'CARDIO', 'MOBILITY', 'STRETCHING']);
export type ExerciseType = z.infer<typeof exerciseTypeSchema>;

export const exerciseMuscleRoleSchema = z.enum(['PRIMARY', 'SECONDARY']);
export type ExerciseMuscleRole = z.infer<typeof exerciseMuscleRoleSchema>;

export const muscleGroupSchema = z.object({
  id: z.string(),
  slug: z.string(),
  name: z.string(),
});
export type MuscleGroup = z.infer<typeof muscleGroupSchema>;

export const equipmentSchema = z.object({
  id: z.string(),
  slug: z.string(),
  name: z.string(),
});
export type Equipment = z.infer<typeof equipmentSchema>;

export const exerciseMuscleSchema = z.object({
  muscleGroup: muscleGroupSchema,
  role: exerciseMuscleRoleSchema,
});
export type ExerciseMuscle = z.infer<typeof exerciseMuscleSchema>;

/** Élément de liste (bibliothèque, recherche). */
export const exerciseSummarySchema = z.object({
  id: z.string(),
  slug: z.string(),
  name: z.string(),
  difficulty: exerciseDifficultySchema,
  type: exerciseTypeSchema,
  isPremium: z.boolean(),
  primaryMuscleGroup: muscleGroupSchema.nullable(),
  equipment: z.array(equipmentSchema),
  /**
   * Photographie du mouvement, servie par le stockage objet. `null` tant
   * qu'aucune n'a été déposée depuis l'administration — l'application affiche
   * alors son repli, jamais l'image d'un autre mouvement.
   */
  imageUrl: z.string().nullable(),
});
export type ExerciseSummary = z.infer<typeof exerciseSummarySchema>;

/** Fiche complète d'un exercice. */
export const exerciseDetailSchema = exerciseSummarySchema.extend({
  description: z.string(),
  instructions: z.array(z.string()),
  tags: z.array(z.string()),
  muscles: z.array(exerciseMuscleSchema),
  /** Maillage 3D du mouvement, quand il existe. Même pipeline que la photo. */
  meshUrl: z.string().nullable(),
});
export type ExerciseDetail = z.infer<typeof exerciseDetailSchema>;
