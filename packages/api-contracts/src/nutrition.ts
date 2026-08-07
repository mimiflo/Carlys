import { z } from 'zod';

/**
 * Contrats nutrition & métabolisme (/api/v1/nutrition/*).
 * Tous les calculs sont faits CÔTÉ SERVEUR — le client affiche.
 */

export const biologicalSexSchema = z.enum(['MALE', 'FEMALE']);
export type BiologicalSex = z.infer<typeof biologicalSexSchema>;

export const activityLevelSchema = z.enum([
  'SEDENTARY',
  'LIGHT',
  'MODERATE',
  'ACTIVE',
  'VERY_ACTIVE',
]);
export type ActivityLevel = z.infer<typeof activityLevelSchema>;

export const nutritionGoalSchema = z.enum(['LOSE_WEIGHT', 'MAINTAIN', 'GAIN_MUSCLE']);
export type NutritionGoal = z.infer<typeof nutritionGoalSchema>;

/** Profil métabolique effectif (poids issu de la dernière mesure corporelle). */
export const metabolicProfileSchema = z.object({
  sex: biologicalSexSchema.nullable(),
  birthDate: z.string().nullable(),
  ageYears: z.number().nullable(),
  heightCm: z.number().nullable(),
  weightKg: z.number().nullable(),
  activityLevel: activityLevelSchema.nullable(),
  goal: nutritionGoalSchema.nullable(),
});
export type MetabolicProfile = z.infer<typeof metabolicProfileSchema>;

export const metabolismMissingFieldSchema = z.enum([
  'sex',
  'birthDate',
  'heightCm',
  'activityLevel',
  'weightKg',
]);
export type MetabolismMissingField = z.infer<typeof metabolismMissingFieldSchema>;

export const bmiCategorySchema = z.enum(['UNDERWEIGHT', 'NORMAL', 'OVERWEIGHT', 'OBESE']);
export type BmiCategory = z.infer<typeof bmiCategorySchema>;

/** Résultats métaboliques — calculés uniquement quand le profil est complet. */
export const metabolismResultSchema = z.object({
  /** Indice de masse corporelle (kg/m²), arrondi au dixième. */
  bmi: z.number(),
  bmiCategory: bmiCategorySchema,
  /** Métabolisme de base (Mifflin-St Jeor), kcal/jour. */
  bmrKcal: z.number(),
  /** Dépense énergétique totale (BMR × activité), kcal/jour. */
  tdeeKcal: z.number(),
  /** Objectif calorique quotidien selon le but visé. */
  targetKcal: z.number(),
  /** Répartition macro-nutriments, grammes/jour. */
  proteinG: z.number(),
  fatG: z.number(),
  carbsG: z.number(),
  /** Hydratation recommandée, ml/jour. */
  waterMl: z.number(),
});
export type MetabolismResult = z.infer<typeof metabolismResultSchema>;

export const metabolismReportSchema = z.object({
  profile: metabolicProfileSchema,
  /** Champs manquants pour calculer — vide quand `metabolism` est présent. */
  missing: z.array(metabolismMissingFieldSchema),
  metabolism: metabolismResultSchema.nullable(),
});
export type MetabolismReport = z.infer<typeof metabolismReportSchema>;
