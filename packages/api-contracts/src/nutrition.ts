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

/**
 * Le moment de la journée d'un repas — une DONNÉE enregistrée, pas une
 * déduction de l'heure : un dîner à 23 h 40 reste un dîner.
 */
export const mealMomentSchema = z.enum(['BREAKFAST', 'LUNCH', 'DINNER', 'SNACK']);
export type MealMoment = z.infer<typeof mealMomentSchema>;

/**
 * Valeurs nutritionnelles POUR 100 g d'un aliment de la base.
 *
 * L'énergie est toujours connue (un aliment sans énergie n'est pas importé).
 * Une macro à `null` veut dire « la table ne la donne pas », jamais zéro ;
 * « traces » et « < x » de la table valent 0.
 */
export const foodPer100gSchema = z.object({
  kcal: z.number(),
  proteinG: z.number().nullable(),
  carbsG: z.number().nullable(),
  fatG: z.number().nullable(),
});
export type FoodPer100g = z.infer<typeof foodPer100gSchema>;

/** Un aliment de la base CIQUAL (/api/v1/nutrition/foods). */
export const foodSchema = z.object({
  /** `alim_code` CIQUAL : la clé à renvoyer dans `components[].foodCode`. */
  code: z.number().int(),
  /** Nom officiel : « Poulet, filet, sans peau, cuit ». */
  name: z.string(),
  /** Le segment avant la première virgule : « Poulet ». */
  shortName: z.string(),
  /** Groupe CIQUAL (« viandes, œufs, poissons et assimilés »), `null` si non décrit. */
  group: z.string().nullable(),
  per100g: foodPer100gSchema,
});
export type Food = z.infer<typeof foodSchema>;

/**
 * La mention que l'écran DOIT afficher près des valeurs issues de la base
 * (Licence Ouverte Etalab 2.0 : réutilisation libre AVEC mention de la
 * source et de la date de sa mise à jour). La date, c'est la version : celle
 * de la table chargée pour /nutrition/foods, celle de CHAQUE ligne pour un
 * repas (`MealComponent.sourceVersion`), qui garde les valeurs de la version
 * où l'aliment a été ajouté.
 */
export const foodAttributionSchema = z.object({
  /** « Source : Anses, Table de composition nutritionnelle des aliments Ciqual ». */
  attribution: z.string(),
  license: z.string(),
  url: z.string(),
});
export type FoodAttribution = z.infer<typeof foodAttributionSchema>;

/** La mention, et la version de la table chargée. */
export const foodSourceSchema = foodAttributionSchema.extend({
  /** Version de la table chargée (« 2020-07-07 »), `null` tant que la base est vide. */
  version: z.string().nullable(),
});
export type FoodSource = z.infer<typeof foodSourceSchema>;

/** `meta` des routes /nutrition/foods : la mention de source à afficher. */
export const foodSourceMetaSchema = z.object({ source: foodSourceSchema });
export type FoodSourceMeta = z.infer<typeof foodSourceMetaSchema>;

/**
 * Bornes d'une composition : 30 aliments au plus, 1 à 5 000 g chacun (deux
 * décimales). Recopiées par le DTO de l'API ; le client les applique à la
 * saisie pour ne pas découvrir un 400 à l'envoi.
 */
export const MEAL_COMPONENTS_MAX = 30;
export const MEAL_COMPONENT_QUANTITY_G_MIN = 1;
export const MEAL_COMPONENT_QUANTITY_G_MAX = 5_000;

/**
 * Ce que le client envoie pour composer un repas : QUELLE ligne, quel
 * aliment, combien.
 *
 * `id` est un UUID généré SUR L'APPAREIL à l'ajout de la ligne, puis
 * conservé : c'est lui qui, dans une correction (PATCH), désigne une ligne
 * DÉJÀ enregistrée. Une ligne ainsi désignée garde son instantané (nom,
 * valeurs pour 100 g, version de la table) et ne change que de quantité ou
 * de place ; seule une ligne à identifiant NEUF relit la base, et y est
 * refusée si l'aliment en a été retiré. Changer l'aliment d'une ligne, c'est
 * une ligne neuve : nouvel `id`. Un identifiant est unique dans tout le
 * journal : deux lignes, même de repas différents, n'en partagent jamais un.
 */
export const mealComponentInputSchema = z.object({
  id: z.string().uuid(),
  foodCode: z.number().int().positive(),
  quantityG: z.number().min(MEAL_COMPONENT_QUANTITY_G_MIN).max(MEAL_COMPONENT_QUANTITY_G_MAX),
});
export type MealComponentInput = z.infer<typeof mealComponentInputSchema>;

/**
 * Un aliment d'un repas COMPOSÉ, tel que le serveur l'a enregistré.
 *
 * `name`, `shortName` et `group` sont l'INSTANTANÉ pris à l'ajout : une
 * nouvelle version de la table ne réécrit pas un repas passé. `kcal` et les
 * macros sont les valeurs DE CE COMPOSANT (pour `quantityG`, pas pour 100 g),
 * arrondies au dixième ; une macro inconnue de la table reste `null`.
 */
export const mealComponentSchema = z.object({
  /** L'UUID que l'appareil a donné à la ligne ; stable d'une correction à l'autre. */
  id: z.string(),
  foodCode: z.number().int(),
  name: z.string(),
  shortName: z.string(),
  group: z.string().nullable(),
  /**
   * La version de la table CIQUAL dont viennent les valeurs de CETTE ligne
   * (« 2020-07-07 ») : à afficher avec la mention `meta.source`. Deux lignes
   * d'un même repas peuvent en porter deux, si l'une a été ajoutée après un
   * changement de version.
   */
  sourceVersion: z.string(),
  quantityG: z.number(),
  kcal: z.number(),
  proteinG: z.number().nullable(),
  carbsG: z.number().nullable(),
  fatG: z.number().nullable(),
});
export type MealComponent = z.infer<typeof mealComponentSchema>;

/**
 * Photo d'un repas (`PUT|GET|DELETE /api/v1/nutrition/meals/:id/photo`).
 *
 * Donnée PERSONNELLE : elle vit dans un stockage privé et n'est servie que
 * par l'API, à la seule personne qui a enregistré le repas. Le client
 * l'envoie en `multipart/form-data`, champ `file`, un seul fichier, en JPEG
 * (compressé sur l'appareil) : le serveur vérifie la signature des OCTETS,
 * pas seulement le type déclaré, et retire toutes les métadonnées (EXIF et
 * position GPS, XMP, IPTC, commentaires) avant de stocker.
 *
 * L'orientation EXIF part avec le reste : le client redresse les pixels
 * AVANT l'envoi, sinon une photo prise en portrait s'affichera couchée.
 */
export const MEAL_PHOTO_MIME_TYPE = 'image/jpeg';
/** 5 Mio : au-delà, 413. Une photo compressée sur l'appareil pèse bien moins. */
export const MEAL_PHOTO_MAX_BYTES = 5 * 1024 * 1024;

/**
 * Ce que le repas dit de sa photo. `updatedAt` (instant UTC, ISO 8601)
 * change à chaque remplacement : c'est la clé de cache du client, qui
 * relit les octets par `GET …/photo` quand elle bouge.
 */
export const mealPhotoSchema = z.object({
  updatedAt: z.string(),
});
export type MealPhoto = z.infer<typeof mealPhotoSchema>;

/** Entrée du journal alimentaire (/api/v1/nutrition/meals). */
export const mealEntrySchema = z.object({
  id: z.string(),
  name: z.string(),
  /** `null` pour un repas enregistré sans moment : le client le déduit de l'heure. */
  moment: mealMomentSchema.nullable(),
  /**
   * Le total du repas. Saisi à la main quand `computed` est faux ; CALCULÉ
   * par le serveur (somme des composants, arrondie à l'entier) quand il est
   * vrai.
   */
  kcal: z.number(),
  /**
   * Ce qui a été mangé, en clair : « 250 g », « 1,5 portion », « 2 pièces ».
   *
   * PUREMENT DESCRIPTIVE : elle ne multiplie NI `kcal` NI les macros, qui
   * restent le total réellement consommé. Un client qui multiplierait par
   * elle compterait deux fois. Les deux champs vont PAR PAIRE — une quantité
   * sans unité ne dit rien — et valent `null` ensemble quand l'entrée a été
   * saisie sans. Pour un repas composé : la somme des grammes, en `GRAM`.
   */
  quantity: z.number().nullable(),
  quantityUnit: mealQuantityUnitSchema.nullable(),
  /**
   * Les trois macros, toutes facultatives et INDÉPENDANTES : `null` veut
   * dire « on ne sait pas », jamais « zéro ». L'écran affiche quatre macros
   * cibles ; il doit pouvoir dire lesquelles il sait comparer. Pour un repas
   * composé : la somme arrondie, ou `null` dès qu'UN composant l'ignore.
   */
  proteinG: z.number().nullable(),
  carbsG: z.number().nullable(),
  fatG: z.number().nullable(),
  /** Instant UTC (ISO 8601) — le découpage en journées appartient au client. */
  eatenAt: z.string(),
  /** Les aliments du repas, dans l'ordre ; vide pour un repas saisi à la main. */
  components: z.array(mealComponentSchema),
  /**
   * Vrai quand `kcal`, les macros et la quantité sont CALCULÉS depuis
   * `components` : ils ne se corrigent alors pas à la main (retirer la
   * composition d'abord, `components: []`).
   */
  computed: z.boolean(),
  /** `null` sans photo. Les octets se lisent par `GET …/meals/:id/photo`. */
  photo: mealPhotoSchema.nullable(),
});
export type MealEntry = z.infer<typeof mealEntrySchema>;

/**
 * `meta` des routes qui rendent des repas (/nutrition/meals…). `source` est
 * présente dès qu'UN des repas rendus porte des aliments de la base : c'est
 * la mention à afficher près de leurs valeurs, avec la `sourceVersion` de
 * chaque ligne. Absente (`meta` vide) quand aucun repas n'en porte : un
 * repas saisi à la main ne montre aucune valeur de la table.
 */
export const mealMetaSchema = z.object({ source: foodAttributionSchema.optional() });
export type MealMeta = z.infer<typeof mealMetaSchema>;
