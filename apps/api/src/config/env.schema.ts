import {
  DEFAULT_RATE_LIMIT_MAX_REQUESTS,
  DEFAULT_RATE_LIMIT_TTL_SECONDS,
} from '@carlys/shared-config';
import { z } from 'zod';
import { DEVELOPMENT_DEFAULTS, refineProductionEnv } from './env.production';

/**
 * Schéma des variables d'environnement de l'API.
 *
 * Le serveur REFUSE de démarrer si une variable essentielle est absente ou
 * invalide : la validation est exécutée par ConfigModule au bootstrap. En
 * production, les valeurs de développement (localhost, Mailpit, MinIO local)
 * sont refusées elles aussi : voir `env.production.ts`.
 */
export const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'staging', 'production']).default('development'),
    PORT: z.coerce.number().int().min(1).max(65535).default(3000),

    DATABASE_URL: z
      .string()
      .min(1)
      .refine(
        (value) => value.startsWith('postgresql://') || value.startsWith('postgres://'),
        'DATABASE_URL doit être une URL de connexion PostgreSQL (postgresql://…)',
      ),
    REDIS_URL: z
      .string()
      .min(1)
      .refine(
        (value) => value.startsWith('redis://') || value.startsWith('rediss://'),
        'REDIS_URL doit être une URL de connexion Redis (redis://…)',
      ),

    CORS_ORIGINS: z.string().default(DEVELOPMENT_DEFAULTS.CORS_ORIGINS),
    LOG_LEVEL: z
      .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'])
      .default('info'),

    /**
     * Nombre de proxys de CONFIANCE devant l'API (terminateur TLS, ingress,
     * équilibreur de charge). 0 en développement : l'adresse de la socket fait
     * foi. 1 derrière un Nginx unique : la dernière adresse de X-Forwarded-For
     * fait foi. Jamais « tout le monde » : un client forgerait son adresse et
     * contournerait la limitation de débit, le verrouillage et l'audit.
     */
    TRUST_PROXY_HOPS: z.coerce.number().int().min(0).default(0),

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

    // ── Authentification ────────────────────────────────────────────────────
    /** Secret de signature des access tokens JWT — obligatoire, jamais par défaut. */
    JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET doit faire au moins 32 caractères'),
    JWT_ACCESS_TTL_SECONDS: z.coerce.number().int().min(60).max(3600).default(900),
    JWT_ISSUER: z.string().min(1).default('carlys-api'),
    JWT_AUDIENCE: z.string().min(1).default('carlys-mobile'),
    REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().min(1).max(365).default(30),

    AUTH_MAX_LOGIN_ATTEMPTS: z.coerce.number().int().min(3).max(20).default(5),
    AUTH_LOCKOUT_MINUTES: z.coerce.number().int().min(1).max(1440).default(15),

    /** Paramètres Argon2id (défauts alignés sur les recommandations OWASP). */
    ARGON2_MEMORY_KIB: z.coerce.number().int().min(8192).default(19456),
    ARGON2_TIME_COST: z.coerce.number().int().min(2).default(2),
    ARGON2_PARALLELISM: z.coerce.number().int().min(1).max(16).default(1),

    EMAIL_VERIFICATION_TTL_HOURS: z.coerce.number().int().min(1).max(168).default(24),
    PASSWORD_RESET_TTL_MINUTES: z.coerce.number().int().min(5).max(1440).default(60),

    // ── Abonnements (Étape 6) ──────────────────────────────────────────────
    /**
     * Secrets de signature des webhooks de paiement. Optionnels : tant qu'ils
     * ne sont pas configurés, l'endpoint correspondant répond 503 — aucun
     * webhook non signé n'est jamais traité.
     */
    STRIPE_WEBHOOK_SECRET: z.string().min(16).optional(),
    REVENUECAT_WEBHOOK_SECRET: z.string().min(16).optional(),

    /**
     * Catalogue d'offres. Les prix sont servis par l'API et JAMAIS écrits dans
     * l'application : un tarif codé dans le mobile deviendrait faux le jour où
     * il change, et il faudrait une mise à jour de l'app pour le corriger.
     *
     * Ils doivent refléter les prix Stripe correspondants — c'est Stripe qui
     * encaisse, ceci n'est que l'affichage.
     */
    SUBSCRIPTION_CURRENCY: z.string().length(3).default('EUR'),
    SUBSCRIPTION_MONTHLY_CENTS: z.coerce.number().int().min(0).default(999),
    SUBSCRIPTION_YEARLY_CENTS: z.coerce.number().int().min(0).default(7990),
    SUBSCRIPTION_TRIAL_DAYS: z.coerce.number().int().min(0).max(90).default(7),

    /**
     * Paiement Stripe. **Optionnels** : sans eux le catalogue reste lisible et
     * l'achat se déclare simplement indisponible — on ne promet pas un
     * paiement qui échouerait, et l'API démarre sans clé payante.
     */
    STRIPE_SECRET_KEY: z.string().min(20).optional(),
    STRIPE_PRICE_MONTHLY: z.string().min(1).optional(),
    STRIPE_PRICE_YEARLY: z.string().min(1).optional(),

    // ── Notifications push (FCM) ───────────────────────────────────────────
    /**
     * Compte de service Firebase, JSON complet (téléchargé depuis la console
     * Firebase → Paramètres → Comptes de service). **Optionnel** : sans lui,
     * l'ENVOI de notifications est désactivé — l'enregistrement des jetons
     * d'appareil, lui, fonctionne toujours (les envois reprennent dès que la
     * clé est fournie, sans redéploiement mobile).
     */
    FIREBASE_SERVICE_ACCOUNT_JSON: z.string().min(2).optional(),

    // ── Coach IA ────────────────────────────────────────────────────────────
    /**
     * Clé du fournisseur de modèle. **Optionnelle** : sans elle, le module se
     * déclare indisponible (503) au lieu d'empêcher le démarrage — l'API doit
     * tourner en développement sans qu'on ait à fournir une clé payante.
     */
    ANTHROPIC_API_KEY: z.string().min(20).optional(),
    COACH_MODEL: z.string().min(1).default('claude-opus-5'),
    /** Plafond par utilisateur et par jour. Le coût du coach est réel. */
    COACH_DAILY_MESSAGE_LIMIT: z.coerce.number().int().min(1).max(500).default(30),
    /** Interrupteur global : coupe la fonctionnalité sans déploiement. */
    COACH_ENABLED: z
      .enum(['true', 'false'])
      .default('true')
      .transform((value) => value === 'true'),

    // ── Stockage objet (MinIO en développement, S3 compatible en production) ─
    //
    // Tout média servi par l'application vit ici : photo d'exercice, maillage 3D
    // à venir. Rien n'est embarqué dans l'app, rien n'est écrit en dur.
    S3_ENDPOINT: z.string().url().default(DEVELOPMENT_DEFAULTS.S3_ENDPOINT),
    S3_REGION: z.string().min(1).default('us-east-1'),
    S3_BUCKET: z.string().min(1).default('carlys-media'),
    S3_ACCESS_KEY_ID: z.string().min(1).default(DEVELOPMENT_DEFAULTS.S3_ACCESS_KEY_ID),
    S3_SECRET_ACCESS_KEY: z.string().min(1).default(DEVELOPMENT_DEFAULTS.S3_SECRET_ACCESS_KEY),
    /**
     * Base publique des URL de médias. MinIO et la plupart des stockages
     * compatibles n'acceptent pas les sous-domaines de bucket en local : le
     * chemin est donc la valeur par défaut.
     */
    S3_PUBLIC_BASE_URL: z.string().url().default(DEVELOPMENT_DEFAULTS.S3_PUBLIC_BASE_URL),
    S3_FORCE_PATH_STYLE: z
      .enum(['true', 'false'])
      .default('true')
      .transform((value) => value === 'true'),
    /** Plafond par fichier. Un maillage 3D pèse plus lourd qu'une photo. */
    MEDIA_MAX_UPLOAD_BYTES: z.coerce.number().int().min(1).default(20_971_520),

    // ── E-mails (Mailpit en développement) ─────────────────────────────────
    SMTP_HOST: z.string().min(1).default(DEVELOPMENT_DEFAULTS.SMTP_HOST),
    SMTP_PORT: z.coerce.number().int().min(1).max(65535).default(1025),
    EMAIL_FROM: z.string().min(3).default(DEVELOPMENT_DEFAULTS.EMAIL_FROM),
    /**
     * Base des liens contenus dans les e-mails (vérification,
     * réinitialisation). Les pages qu'ils ouvrent sont servies par
     * l'application admin Next.js — d'où le défaut sur son port, 3001.
     */
    PUBLIC_APP_URL: z.string().url().default(DEVELOPMENT_DEFAULTS.PUBLIC_APP_URL),
  })
  .superRefine(refineProductionEnv);

export type Env = z.infer<typeof envSchema>;

export function validateEnv(config: Record<string, unknown>): Env {
  const result = envSchema.safeParse(config);
  if (!result.success) {
    const issues = result.error.issues
      .map((issue) => `  - ${issue.path.join('.') || '(racine)'}: ${issue.message}`)
      .join('\n');
    throw new Error(`Configuration invalide — démarrage refusé.\n${issues}`);
  }
  return result.data;
}
