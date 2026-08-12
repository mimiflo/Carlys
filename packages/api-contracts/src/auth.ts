import { z } from 'zod';

/** Contrats du domaine authentification (/api/v1/auth, /api/v1/users/me). */

/** Les 4 profils Carlys — des identités d'usage, jamais des niveaux. */
export const carlysProfileSchema = z.enum(['CONSTRUCTEUR', 'CHALLENGER', 'ATHLETE', 'STRATEGE']);
export type CarlysProfile = z.infer<typeof carlysProfileSchema>;

export const authUserSchema = z.object({
  id: z.string(),
  email: z.string(),
  displayName: z.string(),
  emailVerified: z.boolean(),
  locale: z.string(),
  timezone: z.string(),
  /** `null` tant que la personne n'a pas choisi ; modifiable à tout moment. */
  carlysProfile: carlysProfileSchema.nullable(),
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

/** Contraintes de mot de passe — compatibles gestionnaires de mots de passe. */
export const PASSWORD_MIN_LENGTH = 10;
export const PASSWORD_MAX_LENGTH = 128;

export const registerRequestSchema = z.object({
  email: z.string().email(),
  password: z.string().min(PASSWORD_MIN_LENGTH).max(PASSWORD_MAX_LENGTH),
  displayName: z.string().min(1).max(60),
  deviceName: z.string().max(120).optional(),
  devicePlatform: z.string().max(40).optional(),
});

export const loginRequestSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1).max(PASSWORD_MAX_LENGTH),
  deviceName: z.string().max(120).optional(),
  devicePlatform: z.string().max(40).optional(),
});

export const refreshRequestSchema = z.object({
  refreshToken: z.string().min(1),
});
