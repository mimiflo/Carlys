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

    /**
     * Fenêtre du compte « utilisateurs en ligne » (métrique
     * `carlys_api_online_users`), en secondes.
     *
     * C'est ce compte qui pilote la mise à l'échelle, et la fenêtre décide de
     * son inertie. Trop courte, elle fait osciller la pile au rythme des
     * requêtes ; trop longue, elle continue de compter des gens partis depuis
     * un quart d'heure. Cinq minutes est le compromis retenu : plus long que
     * l'intervalle de supervision, plus court que l'inactivité qui fait
     * qu'on n'utilise plus l'application.
     *
     * Bornée à la minute basse parce que la présence est comptée par seaux
     * d'une minute d'horloge : en dessous, la fenêtre ne voudrait plus rien
     * dire. Bornée à une heure haute pour que les seaux gardés en mémoire
     * dans Redis restent en nombre borné.
     */
    PRESENCE_WINDOW_SECONDS: z.coerce.number().int().min(60).max(3600).default(300),

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

    /**
     * Identifiants produits RevenueCat (achats dans les magasins). Même
     * rôle que les `STRIPE_PRICE_*` : ils disent quel produit du
     * fournisseur ouvre le plan payant, et c'est ce que la commande
     * `subscription-catalog` projette en base. Sans eux, un achat
     * iOS/Android arrive sur un « produit inconnu » et n'accorde rien.
     */
    REVENUECAT_PRODUCT_MONTHLY: z.string().min(1).optional(),
    REVENUECAT_PRODUCT_YEARLY: z.string().min(1).optional(),

    // ── Notifications push (FCM) ───────────────────────────────────────────
    /**
     * Compte de service Firebase, JSON complet (téléchargé depuis la console
     * Firebase → Paramètres → Comptes de service). **Optionnel** : sans lui,
     * l'ENVOI de notifications est désactivé — l'enregistrement des jetons
     * d'appareil, lui, fonctionne toujours (les envois reprennent dès que la
     * clé est fournie, sans redéploiement mobile).
     */
    FIREBASE_SERVICE_ACCOUNT_JSON: z.string().min(2).optional(),

    // ── Connexion sociale (Apple, Google) ───────────────────────────────────
    /**
     * Audiences ACCEPTÉES des jetons d'identité, séparées par des virgules.
     * Google : les client IDs OAuth (Web « serveur » + Android + iOS) de la
     * console Google Cloud. Apple : le bundle ID iOS (et le Services ID web
     * le cas échéant). **Optionnelles** : sans elles, POST /auth/social
     * répond 503 pour le fournisseur concerné au lieu d'empêcher le
     * démarrage — même politique que le coach.
     */
    GOOGLE_OAUTH_CLIENT_IDS: z.string().min(1).optional(),
    APPLE_OAUTH_AUDIENCES: z.string().min(1).optional(),

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
    /**
     * Bucket PRIVÉ : les données personnelles (photo qu'une personne joint à
     * son repas). Aucune lecture anonyme, aucune URL publique : seule l'API
     * le lit, avec les identifiants S3 ci-dessous, et ne sert ses objets
     * qu'à leur propriétaire.
     *
     * POURQUOI UN SECOND BUCKET, ET PAS UN PRÉFIXE DANS LE PREMIER. Le bucket
     * des médias (`S3_BUCKET`) porte une politique de lecture anonyme
     * (`s3:GetObject` sur `<bucket>/*`, posée par `minio-init`) : c'est ce qui
     * permet aux applications de charger une photo d'exercice sans jeton. Une
     * politique S3 s'applique au bucket entier ; un préfixe « privé » y
     * resterait lisible par quiconque devine ou apprend une clé, et une
     * commande `mc anonymous set download` tapée un jour à la main en
     * ouvrirait même la liste. Un bucket distinct, sans aucune politique, ne
     * dépend d'aucune de ces précautions.
     */
    S3_PRIVATE_BUCKET: z
      .string()
      .regex(
        /^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/,
        'S3_PRIVATE_BUCKET doit être un nom de bucket S3 (3 à 63 caractères : minuscules, chiffres, points, tirets)',
      )
      .default('carlys-private'),
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
    /**
     * Authentification du relais. Elle MANQUAIT, et c'est un verrou de
     * production : le transport se construisait sans bloc `auth`, or aucun
     * relais commercial (SES, SendGrid, Mailgun, Postmark, OVH) n'accepte un
     * envoi non authentifié. Sans e-mail sortant, la vérification d'adresse
     * et la réinitialisation de mot de passe ne fonctionnent pas, et
     * l'inscription paraît cassée sans qu'aucun journal ne le dise.
     *
     * Vides par défaut : Mailpit, en développement, n'authentifie rien. Le
     * bloc `auth` n'est passé à nodemailer QUE si un identifiant est fourni,
     * sinon nodemailer tenterait une authentification vide et Mailpit la
     * refuserait.
     */
    SMTP_USER: z.string().default(''),
    SMTP_PASSWORD: z.string().default(''),
    /**
     * TLS implicite dès la connexion (port 465). Les relais en 587 utilisent
     * STARTTLS, que nodemailer négocie tout seul avec `secure: false` : le
     * défaut reste donc `false`, et ce n'est PAS « sans chiffrement ».
     */
    SMTP_SECURE: z.coerce.boolean().default(false),
    EMAIL_FROM: z.string().min(3).default(DEVELOPMENT_DEFAULTS.EMAIL_FROM),
    /**
     * Base des liens contenus dans les e-mails (vérification,
     * réinitialisation). Les pages qu'ils ouvrent sont servies par
     * l'application admin Next.js — d'où le défaut sur son port, 3001.
     */
    PUBLIC_APP_URL: z.string().url().default(DEVELOPMENT_DEFAULTS.PUBLIC_APP_URL),
  })
  .superRefine(refineProductionEnv)
  .superRefine((env, ctx) => {
    // Le même nom pour les deux buckets remettrait les photos de repas dans
    // le bucket lisible sans jeton : la séparation n'existerait plus que sur
    // le papier. Refusé dans TOUS les environnements, développement compris.
    if (env.S3_PRIVATE_BUCKET === env.S3_BUCKET) {
      ctx.addIssue({
        code: 'custom',
        path: ['S3_PRIVATE_BUCKET'],
        message: 'doit différer de S3_BUCKET, dont les objets sont lisibles sans jeton',
      });
    }
  });

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
