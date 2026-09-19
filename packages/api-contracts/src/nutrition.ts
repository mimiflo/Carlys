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
  /** Objectif calorique quotidien selon le but visé, plancher appliqué. */
  targetKcal: z.number(),
  /**
   * Vrai quand le plancher de sécurité a RELEVÉ la cible : `targetKcal` ne
   * vaut alors plus « dépense × facteur d'objectif », et l'écran doit le dire
   * plutôt que d'afficher un chiffre qui contredit sa propre explication.
   */
  targetKcalFloored: z.boolean(),
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

/**
 * L'unité dans laquelle une quantité se dit — grammes, millilitres, portion,
 * pièce. Quatre valeurs, parce que c'est ce qu'on lit sur un emballage ou
 * dans une assiette.
 */
export const mealQuantityUnitSchema = z.enum(['GRAM', 'MILLILITER', 'PORTION', 'PIECE']);
export type MealQuantityUnit = z.infer<typeof mealQuantityUnitSchema>;

/** Entrée du journal alimentaire (/api/v1/nutrition/meals). */
export const mealEntrySchema = z.object({
  id: z.string(),
  name: z.string(),
  kcal: z.number(),
  /**
   * Ce qui a été mangé, en clair : « 250 g », « 1,5 portion », « 2 pièces ».
   *
   * PUREMENT DESCRIPTIVE : elle ne multiplie NI `kcal` NI les macros, qui
   * restent le total réellement consommé. Un client qui multiplierait par
   * elle compterait deux fois. Les deux champs vont PAR PAIRE — une quantité
   * sans unité ne dit rien — et valent `null` ensemble quand l'entrée a été
   * saisie sans.
   */
  quantity: z.number().nullable(),
  quantityUnit: mealQuantityUnitSchema.nullable(),
  /**
   * Les trois macros, toutes facultatives et INDÉPENDANTES : `null` veut
   * dire « on ne sait pas », jamais « zéro ». L'écran affiche quatre macros
   * cibles ; il doit pouvoir dire lesquelles il sait comparer.
   */
  proteinG: z.number().nullable(),
  carbsG: z.number().nullable(),
  fatG: z.number().nullable(),
  /** Instant UTC (ISO 8601) — le découpage en journées appartient au client. */
  eatenAt: z.string(),
});
export type MealEntry = z.infer<typeof mealEntrySchema>;
