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

/**
 * Âge admissible pour le profil métabolique.
 *
 * La date de naissance n'était bornée que par « pas dans le futur » côté DTO,
 * et par 120 ans dans le service — une règle écrite à deux endroits, dont
 * aucun n'était couvert par un test unitaire. Un âge de 0 an passait donc les
 * deux gardes et entrait tel quel dans Mifflin-St Jeor, où il vaut `-5 × 0`.
 *
 * 15 ans est l'audience que le produit se donne lui-même
 * (`docs/legal/terms.md`, `docs/legal/privacy.md` §8). Ce n'est PAS une
 * vérification d'âge à l'inscription — le compte se crée sans date de
 * naissance, et les documents continuent de le dire : c'est le refus d'une
 * valeur dont ces mêmes documents disent qu'elle ne devrait pas exister.
 */
export const AGE_YEARS_MIN = 15;
export const AGE_YEARS_MAX = 120;

/**
 * Les deux dates entre lesquelles une naissance est acceptée, à l'instant
 * donné. Bornes INCLUSES : on naît admissible le jour de ses 15 ans.
 *
 * Passer `now` plutôt que de le lire ici garde la fonction pure, donc
 * testable sans horloge figée — et c'est ce qui permet au DTO de la rappeler
 * à chaque requête au lieu de figer un intervalle au démarrage du serveur.
 *
 * LES BORNES SONT DES JOURNÉES, PAS DES INSTANTS, et ce n'est pas un détail
 * de confort : un âge se compte en jours civils. Comparer à la milliseconde
 * rendait la règle dépendante de l'heure de la requête — « né il y a
 * exactement 120 ans » passait ou non selon les quelques millisecondes
 * écoulées entre la construction de la date et la validation. C'est
 * précisément ce qui a rendu un test vert en local et rouge en CI.
 *
 * `earliest` tombe donc au DÉBUT de la journée des 120 ans, et `latest` à sa
 * FIN pour les 15 ans : on est admissible tout le jour de son anniversaire,
 * quelle que soit l'heure de naissance.
 */
export function birthDateRange(now: Date): { earliest: Date; latest: Date } {
  const earliest = new Date(now);
  earliest.setUTCFullYear(earliest.getUTCFullYear() - AGE_YEARS_MAX);
  earliest.setUTCHours(0, 0, 0, 0);
  const latest = new Date(now);
  latest.setUTCFullYear(latest.getUTCFullYear() - AGE_YEARS_MIN);
  latest.setUTCHours(23, 59, 59, 999);
  return { earliest, latest };
}

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
  /** ISO 8601, dans l'intervalle `birthDateRange` (de 15 à 120 ans). */
  birthDate: z.string().datetime().optional(),
  heightCm: heightCmSchema.optional(),
  activityLevel: activityLevelSchema.optional(),
  nutritionGoal: nutritionGoalSchema.optional(),
});
export type UpdateProfileRequest = z.infer<typeof updateProfileRequestSchema>;
