import { z } from 'zod';
import { carlysProfileSchema } from './auth';
import { activityLevelSchema, biologicalSexSchema, nutritionGoalSchema } from './nutrition';

/**
 * Profil de compte — `PATCH /users/me`.
 *
 * POURQUOI CE FICHIER EXISTE. Les bornes du profil ne vivaient QUE dans le
 * DTO NestJS. Les clients les recopiaient donc au jugé, et divergeaient :
 * l'écran de profil métabolique du mobile vérifiait l'intervalle de la taille
 * mais pas sa précision, alors que le serveur refuse au-delà d'une décimale —
 * une saisie « 175,25 » passait la validation locale pour être rejetée par
 * l'API, sans que l'écran puisse dire pourquoi. Une borne qui n'est écrite
 * qu'à un endroit finit toujours par être devinée ailleurs.
 *
 * Les constantes qui suivent sont donc la SOURCE, et le DTO les applique.
 */

/** Taille en centimètres — une décimale, pas deux : c'est un corps humain. */
export const HEIGHT_CM_MIN = 80;
export const HEIGHT_CM_MAX = 250;
export const HEIGHT_CM_DECIMALS = 1;

export const DISPLAY_NAME_MAX_LENGTH = 60;

/** Locale BCP 47 telle que l'API l'accepte : `fr` ou `fr-FR`. */
export const LOCALE_PATTERN = /^[a-z]{2}(-[A-Z]{2})?$/;

/**
 * Une taille valide : dans l'intervalle ET avec au plus une décimale.
 *
 * Le contrôle de précision se fait sur la valeur ARRONDIE au dixième, jamais
 * sur l'écriture décimale : `175.1` n'est pas représentable exactement en
 * binaire, et une comparaison naïve de chaînes refuserait une saisie
 * parfaitement légitime.
 */
export const heightCmSchema = z
  .number()
  .min(HEIGHT_CM_MIN)
  .max(HEIGHT_CM_MAX)
  .refine((value) => Math.abs(value * 10 - Math.round(value * 10)) < 1e-9, {
    message: 'Une seule décimale au maximum.',
  });

export const updateProfileRequestSchema = z.object({
  displayName: z.string().trim().min(1).max(DISPLAY_NAME_MAX_LENGTH).optional(),
  locale: z.string().regex(LOCALE_PATTERN).optional(),
  /** Identifiant IANA ; le serveur le vérifie en plus contre ICU. */
  timezone: z.string().min(1).max(60).optional(),
  carlysProfile: carlysProfileSchema.optional(),
  sex: biologicalSexSchema.optional(),
  /** ISO 8601, jamais dans le futur. */
  birthDate: z.string().datetime().optional(),
  heightCm: heightCmSchema.optional(),
  activityLevel: activityLevelSchema.optional(),
  nutritionGoal: nutritionGoalSchema.optional(),
});
export type UpdateProfileRequest = z.infer<typeof updateProfileRequestSchema>;
