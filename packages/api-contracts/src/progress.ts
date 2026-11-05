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

export const lifetimeStatsSchema = z.object({
  completedSessions: z.number(),
  /** Une entrée par semaine ACTIVE, de la plus ancienne à la plus récente. */
  weeks: z.array(lifetimeWeekSchema),
});
export type LifetimeStats = z.infer<typeof lifetimeStatsSchema>;

/**
 * LA FRISE — ce qui s'est passé, dans l'ordre.
 *
 * Six types d'événements, un contrat commun. Trois viennent de tables déjà
 * datées (séances, mesures, leçons) et sont dérivés à la lecture ; trois
 * sont des FRANCHISSEMENTS matérialisés dans `ProgressMilestone`, parce
 * qu'ils ne correspondent à aucune ligne existante.
 */
export const progressEventKindSchema = z.enum([
  'SESSION',
  'MEASURE',
  'LESSON',
  'RECORD',
  'REWARD',
  'TITLE',
]);

export const progressEventSchema = z.object({
  /** Identifiant de l'événement dans la frise, stable et opaque. */
  id: z.string(),
  kind: progressEventKindSchema,
  occurredAt: z.string(),
  /** Ce qu'il faut pour écrire la ligne, sans rejouer le moindre calcul. */
  payload: z.record(z.string(), z.unknown()),
});
export type ProgressEvent = z.infer<typeof progressEventSchema>;

/** Page maximale d'une frise. Le défaut est plus petit, voir le DTO. */
export const TIMELINE_MAX_PAGE_SIZE = 50;

export const progressTimelineSchema = z.object({
  items: z.array(progressEventSchema),
  nextCursor: z.string().nullable(),
  hasMore: z.boolean(),
});
export type ProgressTimeline = z.infer<typeof progressTimelineSchema>;

export const milestoneKindSchema = z.enum(['RECORD', 'REWARD', 'TITLE']);
export type MilestoneKind = z.infer<typeof milestoneKindSchema>;

/**
 * Plafond d'un import : le catalogue compte 22 récompenses et 4 titres.
 * Cent laisse la place à trois fois ça sans ouvrir un tuyau.
 */
export const MILESTONES_IMPORT_MAX = 100;

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

export const exerciseProgressionSchema = z.object({
  exerciseId: z.string(),
  exerciseName: z.string(),
  records: z.array(personalRecordSchema),
  points: z.array(exerciseProgressionPointSchema),
});
export type ExerciseProgression = z.infer<typeof exerciseProgressionSchema>;

/**
 * Le poids, le taux de masse grasse, puis les sept MENSURATIONS (des tours,
 * en centimètres) : taille, hanches, poitrine, bras, cuisse, mollet, cou.
 */
export const bodyMetricTypeSchema = z.enum([
  'WEIGHT_KG',
  'BODY_FAT_PERCENT',
  'WAIST_CM',
  'HIPS_CM',
  'CHEST_CM',
  'ARM_CM',
  'THIGH_CM',
  'CALF_CM',
  'NECK_CM',
]);
export type BodyMetricType = z.infer<typeof bodyMetricTypeSchema>;

/**
 * Bornes PLAUSIBLES d'une mesure, par type : au-delà, c'est une faute de
 * frappe, pas une mesure. Le poids et la masse grasse gardent les bornes
 * qu'ils ont depuis l'Étape 5 (1 à 500, deux décimales) ; chaque tour a les
 * siennes, en cm, à une décimale — un mètre ruban ne lit pas mieux.
 *
 * Les bornes hautes laissent passer les morphologies extrêmes (un tour de
 * taille de 250 cm existe) : refuser une mesure vraie serait pire que
 * laisser passer une valeur rare.
 */
export const BODY_METRIC_BOUNDS: Readonly<
  Record<BodyMetricType, { min: number; max: number; decimals: number }>
> = {
  WEIGHT_KG: { min: 1, max: 500, decimals: 2 },
  BODY_FAT_PERCENT: { min: 1, max: 500, decimals: 2 },
  WAIST_CM: { min: 40, max: 250, decimals: 1 },
  HIPS_CM: { min: 50, max: 250, decimals: 1 },
  CHEST_CM: { min: 50, max: 250, decimals: 1 },
  ARM_CM: { min: 10, max: 100, decimals: 1 },
  THIGH_CM: { min: 20, max: 150, decimals: 1 },
  CALF_CM: { min: 15, max: 100, decimals: 1 },
  NECK_CM: { min: 20, max: 80, decimals: 1 },
};

export const bodyMetricSchema = z.object({
  id: z.string(),
  metricType: bodyMetricTypeSchema,
  value: z.number(),
  measuredAt: z.string(),
});
export type BodyMetric = z.infer<typeof bodyMetricSchema>;
