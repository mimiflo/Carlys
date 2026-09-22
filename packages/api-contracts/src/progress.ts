import { z } from 'zod';

/** Contrats de la progression (/api/v1/progress, /api/v1/body-metrics). */

export const progressPeriodSchema = z.enum(['week', 'month', 'year']);
export type ProgressPeriod = z.infer<typeof progressPeriodSchema>;

/** Point de série pour les graphiques (regroupement par jour/semaine/mois). */
export const progressPointSchema = z.object({
  bucketStart: z.string(),
  sessionsCount: z.number(),
  volumeKg: z.number(),
});
export type ProgressPoint = z.infer<typeof progressPointSchema>;

export const progressOverviewSchema = z.object({
  period: progressPeriodSchema,
  from: z.string(),
  to: z.string(),
  sessionsCount: z.number(),
  setsCount: z.number(),
  totalVolumeKg: z.number(),
  totalDurationSeconds: z.number(),
  points: z.array(progressPointSchema),
});
export type ProgressOverview = z.infer<typeof progressOverviewSchema>;

/**
 * Ce que la VIE ENTIÈRE compte, pour les récompenses.
 *
 * Des FAITS, jamais une règle : le serveur dit combien de séances et
 * quelles semaines, le moteur de récompenses (mobile) décide seul ce qu'est
 * une « meilleure série » ou une « semaine équilibrée ». Calculer ces règles
 * ici les dupliquerait, et deux copies divergent.
 *
 * Pourquoi le serveur : le mobile les dérivait de son historique LOCAL,
 * plafonné à 60 séances au rapatriement. Sur un compte à 200 séances, un
 * téléphone neuf en voyait 60 — et une récompense déjà gagnée disparaissait.
 */
export const lifetimeWeekSchema = z.object({
  /** Lundi qui ouvre la semaine, `YYYY-MM-DD` dans le fuseau de la personne. */
  mondayOn: z.string(),
  /** Séances TERMINÉES cette semaine-là. */
  sessions: z.number(),
});
export type LifetimeWeek = z.infer<typeof lifetimeWeekSchema>;

export const lifetimeStatsSchema = z.object({
  completedSessions: z.number(),
  /** Une entrée par semaine ACTIVE, de la plus ancienne à la plus récente. */
  weeks: z.array(lifetimeWeekSchema),
});
export type LifetimeStats = z.infer<typeof lifetimeStatsSchema>;

export const personalRecordTypeSchema = z.enum(['MAX_WEIGHT', 'MAX_REPS', 'MAX_SET_VOLUME']);
export type PersonalRecordType = z.infer<typeof personalRecordTypeSchema>;

export const personalRecordSchema = z.object({
  id: z.string(),
  exerciseId: z.string().nullable(),
  exerciseName: z.string(),
  recordType: personalRecordTypeSchema,
  /** Valeur du record : kg, répétitions ou kg de volume selon le type. */
  value: z.number(),
  reps: z.number().nullable(),
  weightKg: z.number().nullable(),
  achievedAt: z.string(),
});
export type PersonalRecord = z.infer<typeof personalRecordSchema>;

/** Progression sur un exercice : meilleure charge et volume par séance. */
export const exerciseProgressionPointSchema = z.object({
  sessionId: z.string(),
  date: z.string(),
  maxWeightKg: z.number().nullable(),
  maxReps: z.number().nullable(),
  volumeKg: z.number(),
  /**
   * Ce que la séance a parcouru et chronométré sur CET exercice.
   *
   * SOMMÉS, jamais maximisés : trois fractionnés de 400 m font 1 200 m de
   * course, alors qu'une charge ne s'additionne pas d'une série à l'autre.
   * Zéro sur un exercice de fonte, ce qui est exact — un tapis et un développé
   * couché ne se lisent pas sur la même courbe, et c'est le client qui choisit
   * laquelle tracer.
   */
  distanceMeters: z.number(),
  durationSeconds: z.number(),
});
export type ExerciseProgressionPoint = z.infer<typeof exerciseProgressionPointSchema>;

export const exerciseProgressionSchema = z.object({
  exerciseId: z.string(),
  exerciseName: z.string(),
  records: z.array(personalRecordSchema),
  points: z.array(exerciseProgressionPointSchema),
});
export type ExerciseProgression = z.infer<typeof exerciseProgressionSchema>;

export const bodyMetricTypeSchema = z.enum(['WEIGHT_KG', 'BODY_FAT_PERCENT']);
export type BodyMetricType = z.infer<typeof bodyMetricTypeSchema>;

export const bodyMetricSchema = z.object({
  id: z.string(),
  metricType: bodyMetricTypeSchema,
  value: z.number(),
  measuredAt: z.string(),
});
export type BodyMetric = z.infer<typeof bodyMetricSchema>;

/**
 * Correction d'une mesure déjà enregistrée : la valeur, la date, ou les deux.
 *
 * Le TYPE ne se corrige pas — un poids ne devient pas un taux de masse
 * grasse. Se tromper de type se répare en supprimant la ligne et en en
 * créant une autre, ce que l'API permet déjà.
 *
 * `refine` plutôt que deux champs obligatoires : un corps vide n'est pas une
 * correction, c'est un appel qui ne veut rien dire. Le refuser tôt évite une
 * écriture inutile et un `updatedAt` qui bougerait pour rien.
 */
export const updateBodyMetricRequestSchema = z
  .object({
    value: z.number().min(1).max(500).optional(),
    measuredAt: z.string().optional(),
  })
  .refine(
    (body) => body.value !== undefined || body.measuredAt !== undefined,
    'Rien à corriger : donne au moins la valeur ou la date.',
  );
export type UpdateBodyMetricRequest = z.infer<typeof updateBodyMetricRequestSchema>;
