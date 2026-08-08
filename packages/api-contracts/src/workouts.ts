import { z } from 'zod';

/**
 * Contrats des séances (/api/v1/workout-sessions, /api/v1/workout-sets).
 *
 * Les identifiants sont des UUID générés SUR L'APPAREIL : la création est
 * idempotente (rejouer la même requête ne duplique jamais la donnée).
 */

export const workoutSessionStatusSchema = z.enum(['IN_PROGRESS', 'COMPLETED', 'ABANDONED']);
export type WorkoutSessionStatus = z.infer<typeof workoutSessionStatusSchema>;

export const workoutSetKindSchema = z.enum(['WARMUP', 'NORMAL', 'DROP']);
export type WorkoutSetKind = z.infer<typeof workoutSetKindSchema>;

export const workoutSetSchema = z.object({
  id: z.string(),
  exerciseId: z.string().nullable(),
  /** Dénormalisé : l'historique survit aux évolutions du catalogue. */
  exerciseName: z.string(),
  position: z.number(),
  kind: workoutSetKindSchema,
  reps: z.number().nullable(),
  weightKg: z.number().nullable(),
  durationSeconds: z.number().nullable(),
  distanceMeters: z.number().nullable(),
  rpe: z.number().nullable(),
  restSeconds: z.number().nullable(),
  completedAt: z.string(),
  /**
   * Cible AFFICHÉE au moment où la série a été validée (null hors modèle).
   * Fait historique : jamais réécrit par une correction ultérieure.
   */
  plannedReps: z.number().nullable(),
  plannedWeightKg: z.number().nullable(),
});
export type WorkoutSet = z.infer<typeof workoutSetSchema>;

export const workoutSessionSummarySchema = z.object({
  id: z.string(),
  name: z.string().nullable(),
  status: workoutSessionStatusSchema,
  startedAt: z.string(),
  endedAt: z.string().nullable(),
  durationSeconds: z.number().nullable(),
  setsCount: z.number(),
  /** Somme reps × charge des séries avec charge, arrondie au kg. */
  totalVolumeKg: z.number(),
  /** Modèle lancé, s'il y en a un — null pour une séance libre. */
  templateId: z.string().nullable(),
  /** Nom du modèle AU MOMENT DU LANCEMENT : provenance immuable. */
  templateName: z.string().nullable(),
});
export type WorkoutSessionSummary = z.infer<typeof workoutSessionSummarySchema>;

export const workoutSessionDetailSchema = workoutSessionSummarySchema.extend({
  notes: z.string().nullable(),
  sets: z.array(workoutSetSchema),
});
export type WorkoutSessionDetail = z.infer<typeof workoutSessionDetailSchema>;

/** Bornes de validation partagées client/serveur. */
export const WORKOUT_LIMITS = {
  repsMax: 1_000,
  weightKgMax: 1_000,
  durationSecondsMax: 24 * 3_600,
  distanceMetersMax: 1_000_000,
  rpeMin: 1,
  rpeMax: 10,
  restSecondsMax: 3_600,
  nameMax: 120,
  notesMax: 2_000,
} as const;
