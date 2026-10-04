import { z } from 'zod';

/** Contrats du domaine authentification (/api/v1/auth, /api/v1/users/me). */

/** Les 4 profils Carlys — des identités d'usage, jamais des niveaux. */
export const carlysProfileSchema = z.enum(['CONSTRUCTEUR', 'CHALLENGER', 'ATHLETE', 'STRATEGE']);
export type CarlysProfile = z.infer<typeof carlysProfileSchema>;

/**
 * Les 4 styles de voix du Mentor Carlys — un axe INDÉPENDANT du profil :
 * le profil décrit l'utilisateur, le style décrit la VOIX qui lui parle.
 * Les deux se composent côté serveur (4 briefings + 4, jamais 16).
 */
export const mentorStyleSchema = z.enum(['BIENVEILLANT', 'EXIGEANT', 'ATHLETE', 'PHILOSOPHE']);
export type MentorStyle = z.infer<typeof mentorStyleSchema>;

/**
 * Objectif d'ENTRAÎNEMENT — un axe distinct de l'objectif nutritionnel
 * (deux questions, deux réponses). Entrée première de la génération de
 * programme (Plan 4) ; extensible côté serveur, les clients rendent `null`
 * pour toute valeur inconnue.
 */
export const trainingGoalSchema = z.enum([
  'FAT_LOSS',
  'MUSCLE_GAIN',
  'RECOMPOSITION',
  'HYROX',
  'MARATHON',
  'MAINTENANCE',
  'STRENGTH',
  'CALISTHENICS',
]);
export type TrainingGoal = z.infer<typeof trainingGoalSchema>;

export const authUserSchema = z.object({
  id: z.string(),
  email: z.string(),
  displayName: z.string(),
  emailVerified: z.boolean(),
  locale: z.string(),
  timezone: z.string(),
  /** `null` tant que la personne n'a pas choisi ; modifiable à tout moment. */
  carlysProfile: carlysProfileSchema.nullable(),
  /** Style de voix du Mentor — `null` tant que la personne n'a pas choisi. */
  mentorStyle: mentorStyleSchema.nullable(),
  /** Objectif d'entraînement — `null` tant que la personne n'a pas choisi. */
  trainingGoal: trainingGoalSchema.nullable(),
  createdAt: z.string(),
});

export type AuthUser = z.infer<typeof authUserSchema>;

export const authTokensSchema = z.object({
  /** JWT courte durée à présenter en Authorization: Bearer. */
  accessToken: z.string(),
  /** Durée de vie de l'access token, en secondes. */
  accessTokenExpiresIn: z.number(),
  /** Jeton opaque à usage unique — remplacé à chaque rafraîchissement. */
  refreshToken: z.string(),
  /** Expiration absolue de la session (ISO 8601, UTC). */
  refreshTokenExpiresAt: z.string(),
});

export type AuthTokens = z.infer<typeof authTokensSchema>;

export const authResultSchema = z.object({
  user: authUserSchema,
  tokens: authTokensSchema,
});

export type AuthResult = z.infer<typeof authResultSchema>;

export const authSessionSchema = z.object({
  id: z.string(),
  deviceName: z.string().nullable(),
  devicePlatform: z.string().nullable(),
  ipAddress: z.string().nullable(),
  userAgent: z.string().nullable(),
  createdAt: z.string(),
  lastUsedAt: z.string(),
  /** Vraie pour la session qui effectue la requête. */
  current: z.boolean(),
});

export type AuthSession = z.infer<typeof authSessionSchema>;

/**
 * Réponse de `DELETE /users/me` (200) : le compte EST supprimé.
 *
 * Un abonnement Stripe est déjà résilié à ce stade — la suppression est
 * refusée (503) tant qu'il ne l'est pas. Un abonnement pris dans un magasin
 * d'applications (App Store, Play Store), lui, ne se résilie que dans le
 * magasin : `storeSubscriptionStillActive` vaut alors `true`, et l'appli dit
 * à la personne de le résilier elle-même, sans quoi elle reste prélevée.
 */
export const accountDeletionResultSchema = z.object({
  storeSubscriptionStillActive: z.boolean(),
});

export type AccountDeletionResult = z.infer<typeof accountDeletionResultSchema>;

/** Contraintes de mot de passe : voir `password-limits.ts` (module sans Zod). */
export { PASSWORD_MAX_LENGTH, PASSWORD_MIN_LENGTH } from './password-limits';

/** Fournisseurs de connexion sociale acceptés par POST /auth/social. */
export const socialProviderSchema = z.enum(['apple', 'google']);
export type SocialProvider = z.infer<typeof socialProviderSchema>;

/** Borne large : un jeton d'identité Apple/Google fait ~1-2 Ko. */
export const SOCIAL_ID_TOKEN_MAX_LENGTH = 8192;
