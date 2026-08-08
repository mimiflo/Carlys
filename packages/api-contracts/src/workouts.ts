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

/**
 * Série PRÉVUE d'une séance : copie aplatie du modèle au moment du lancement.
 *
 * C'est une COPIE, pas un lien vivant — modifier ou supprimer le modèle plus
 * tard ne change rien à une séance déjà lancée. Le serveur la conserve pour
 * qu'une séance commencée sur un appareil se reprenne telle quelle sur un
 * autre : sans elle, l'appareil qui reprend voit les séries faites mais plus
 * aucune cible.
 *
 * Les identifiants viennent de l'appareil, comme ceux des séances et séries.
 */
export const workoutSessionPlanItemSchema = z.object({
  id: z.string(),
  /** Rang de l'exercice dans la séance, à partir de 0. */
  exercisePosition: z.number(),
  exerciseId: z.string().nullable(),
  /** Dénormalisé : le plan survit aux évolutions du catalogue. */
  exerciseName: z.string(),
  /** Rang de la série DANS l'exercice, à partir de 0. */
  setPosition: z.number(),
  kind: workoutSetKindSchema,
  targetReps: z.number().nullable(),
  targetWeightKg: z.number().nullable(),
  restSeconds: z.number().nullable(),
  /** Série réalisée qui a honoré cette prévision, sinon null. */
  doneSetId: z.string().nullable(),
  /** Prévision explicitement passée par l'utilisateur. */
  skipped: z.boolean(),
});
export type WorkoutSessionPlanItem = z.infer<typeof workoutSessionPlanItemSchema>;

export const workoutSessionDetailSchema = workoutSessionSummarySchema.extend({
  notes: z.string().nullable(),
  sets: z.array(workoutSetSchema),
  /** Vide pour une séance libre (lancée sans modèle). */
  plan: z.array(workoutSessionPlanItemSchema),
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
  /**
   * Plafond du plan transmis à la création d'une séance : le maximum
   * atteignable par un modèle (WORKOUT_TEMPLATE_LIMITS, 30 × 20).
   */
  planItemsMax: 600,
} as const;
