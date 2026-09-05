import { type z } from 'zod';

/**
 * Valeurs de DÉVELOPPEMENT des variables qui n'ont de sens qu'explicites en
 * production.
 *
 * Elles servent de défaut au schéma, pour que l'API démarre sur un poste sans
 * configuration, et de liste de refus en production : en garder une ferait
 * démarrer l'API « avec succès » en envoyant ses e-mails à un Mailpit
 * inexistant, en servant des URL de médias vers localhost et en pointant les
 * liens des e-mails vers une machine locale.
 *
 * PUBLIC_APP_URL pointe vers l'application admin Next.js (3001) : c'est elle
 * qui sert les pages web publiques ouvertes par ces liens (réinitialisation
 * de mot de passe, vérification d'e-mail, confidentialité, conditions,
 * abonnement) — jamais l'API elle-même.
 */
export const DEVELOPMENT_DEFAULTS = {
  CORS_ORIGINS: 'http://localhost:3001',
  S3_ENDPOINT: 'http://localhost:9000',
  S3_ACCESS_KEY_ID: 'carlys-dev',
  S3_SECRET_ACCESS_KEY: 'carlys-dev-secret',
  S3_PUBLIC_BASE_URL: 'http://localhost:9000/carlys-media',
  SMTP_HOST: 'localhost',
  EMAIL_FROM: 'Carlys <no-reply@carlys.local>',
  PUBLIC_APP_URL: 'http://localhost:3001',
} as const;

type ProductionKey = keyof typeof DEVELOPMENT_DEFAULTS;

/** Ce que le raffinement lit : le sous-ensemble du schéma qui le concerne. */
export type ProductionSensitiveEnv = { NODE_ENV: string } & Record<ProductionKey, string>;

/** URL que des tiers (téléphone, navigateur, client e-mail) doivent joindre. */
const PUBLIC_URL_KEYS: readonly ProductionKey[] = [
  'S3_PUBLIC_BASE_URL',
  'PUBLIC_APP_URL',
  'CORS_ORIGINS',
];
const HTTPS_KEYS: readonly ProductionKey[] = ['S3_PUBLIC_BASE_URL', 'PUBLIC_APP_URL'];
const CREDENTIAL_KEYS: readonly ProductionKey[] = ['S3_ACCESS_KEY_ID', 'S3_SECRET_ACCESS_KEY'];

const LOOPBACK = /localhost|127\.0\.0\.1/i;
const DEVELOPMENT_CREDENTIAL_PREFIX = 'carlys-dev';

/**
 * En production, refuse ce qui ne peut être qu'un oubli : une valeur de
 * développement restée en place, une URL publique vers la machine locale, un
 * identifiant de MinIO local, une URL publique en clair. Sans effet hors
 * production : le poste de développement et les tests gardent leurs défauts.
 */
export function refineProductionEnv(env: ProductionSensitiveEnv, ctx: z.RefinementCtx): void {
  if (env.NODE_ENV !== 'production') {
    return;
  }

  const refused = new Set<ProductionKey>();
  const refuse = (key: ProductionKey, message: string): void => {
    refused.add(key);
    ctx.addIssue({ code: 'custom', path: [key], message });
  };

  for (const key of Object.keys(DEVELOPMENT_DEFAULTS) as ProductionKey[]) {
    if (env[key] === DEVELOPMENT_DEFAULTS[key]) {
      refuse(key, 'doit être défini explicitement en production (valeur de développement refusée)');
    }
  }
  for (const key of PUBLIC_URL_KEYS) {
    if (!refused.has(key) && LOOPBACK.test(env[key])) {
      refuse(key, 'ne peut pas pointer vers localhost ou 127.0.0.1 en production');
    }
  }
  for (const key of HTTPS_KEYS) {
    if (!refused.has(key) && !env[key].startsWith('https://')) {
      refuse(key, 'doit être une URL https:// en production');
    }
  }
  for (const key of CREDENTIAL_KEYS) {
    if (!refused.has(key) && env[key].startsWith(DEVELOPMENT_CREDENTIAL_PREFIX)) {
      refuse(
        key,
        `identifiant de développement (${DEVELOPMENT_CREDENTIAL_PREFIX}*) refusé en production`,
      );
    }
  }
}
