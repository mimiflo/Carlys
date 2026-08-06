import {
  DEFAULT_RATE_LIMIT_MAX_REQUESTS,
  DEFAULT_RATE_LIMIT_TTL_SECONDS,
} from '@carlys/shared-config';
import { z } from 'zod';

/**
 * Schéma des variables d'environnement de l'API.
 *
 * Le serveur REFUSE de démarrer si une variable essentielle est absente ou
 * invalide : la validation est exécutée par ConfigModule au bootstrap.
 */
export const envSchema = z.object({
  NODE_ENV: z
    .enum(['development', 'test', 'staging', 'production'])
    .default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),

  DATABASE_URL: z
    .string()
    .min(1)
    .refine(
      (value) =>
        value.startsWith('postgresql://') || value.startsWith('postgres://'),
      'DATABASE_URL doit être une URL de connexion PostgreSQL (postgresql://…)',
    ),
  REDIS_URL: z
    .string()
    .min(1)
    .refine(
      (value) => value.startsWith('redis://') || value.startsWith('rediss://'),
      'REDIS_URL doit être une URL de connexion Redis (redis://…)',
    ),

  CORS_ORIGINS: z.string().default('http://localhost:3001'),
  LOG_LEVEL: z
    .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'])
    .default('info'),

  RATE_LIMIT_TTL_SECONDS: z.coerce
    .number()
    .int()
    .positive()
    .default(DEFAULT_RATE_LIMIT_TTL_SECONDS),
  RATE_LIMIT_MAX_REQUESTS: z.coerce
    .number()
    .int()
    .positive()
    .default(DEFAULT_RATE_LIMIT_MAX_REQUESTS),

  /** Par défaut : activé partout sauf en production. */
  SWAGGER_ENABLED: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => (value === undefined ? undefined : value === 'true')),

  /** Requis pour exposer /metrics en production (Bearer token). */
  METRICS_TOKEN: z.string().min(16).optional(),
});

export type Env = z.infer<typeof envSchema>;

export function validateEnv(config: Record<string, unknown>): Env {
  const result = envSchema.safeParse(config);
  if (!result.success) {
    const issues = result.error.issues
      .map(
        (issue) =>
          `  - ${issue.path.join('.') || '(racine)'}: ${issue.message}`,
      )
      .join('\n');
    throw new Error(`Configuration invalide — démarrage refusé.\n${issues}`);
  }
  return result.data;
}
