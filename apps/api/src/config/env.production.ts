import { type z } from 'zod';
import { PUBLISHED_DEVELOPMENT_SECRETS } from './published-secrets';

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
export type ProductionSensitiveEnv = {
  NODE_ENV: string;
  TRUST_PROXY_HOPS: number;
  COACH_API_BASE_URL?: string;
  COACH_API_KEY?: string;
  COACH_WORKER_URLS?: string;
} & Record<ProductionKey, string>;

/** URL que des tiers (téléphone, navigateur, client e-mail) doivent joindre. */
const PUBLIC_URL_KEYS: readonly ProductionKey[] = [
  'S3_PUBLIC_BASE_URL',
  'PUBLIC_APP_URL',
  'CORS_ORIGINS',
];
/**
 * Clés dont la valeur EST une URL, contrôlées telles quelles.
 *
 * CORS_ORIGINS n'y figure pas : ce n'est pas une URL mais une LISTE séparée par
 * des virgules, et `startsWith('https://')` n'y verrait que la première entrée.
 * Un contrôle qui n'inspecte qu'un élément sur trois est pire qu'aucun — il
 * fait croire que la garde a regardé. La liste est donc traitée à part, entrée
 * par entrée, plus bas.
 */
const HTTPS_KEYS: readonly ProductionKey[] = ['S3_PUBLIC_BASE_URL', 'PUBLIC_APP_URL'];
const CREDENTIAL_KEYS: readonly ProductionKey[] = ['S3_ACCESS_KEY_ID', 'S3_SECRET_ACCESS_KEY'];

const LOOPBACK = /localhost|127\.0\.0\.1/i;
const PLACEHOLDER = 'CHANGE_MOI';
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

  const refused = new Set<string>();
  const refuse = (key: string, message: string): void => {
    refused.add(key);
    ctx.addIssue({ code: 'custom', path: [key], message });
  };

  // Un gabarit (`CHANGE_MOI_…`) resté en place est PUBLIÉ dans le dépôt :
  // avec lui en JWT_ACCESS_SECRET, n'importe qui forge une session à
  // n'importe quel compte. Toute variable lue par l'API, sans exception.
  for (const [key, value] of Object.entries(env as Record<string, unknown>)) {
    if (typeof value === 'string' && value.includes(PLACEHOLDER)) {
      ctx.addIssue({
        code: 'custom',
        path: [key],
        message: `valeur de gabarit (${PLACEHOLDER}…) refusée en production : à remplacer`,
      });
    }
  }

  // Derrière Nginx, 0 ferait voir à l'API UNE seule adresse pour tout le
  // trafic : la limite de connexion (10/min) deviendrait celle de la
  // plateforme entière, et l'audit noterait l'adresse du proxy.
  if (env.TRUST_PROXY_HOPS < 1) {
    ctx.addIssue({
      code: 'custom',
      path: ['TRUST_PROXY_HOPS'],
      message: 'doit valoir au moins 1 en production (l’API est derrière un proxy)',
    });
  }

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
  // CORS_ORIGINS, entrée par entrée. Une origine en clair dans la liste de
  // production est un oubli, pas un choix : le navigateur appelle l'API depuis
  // une page servie en https, et une origine `http://` ne correspondra donc
  // jamais — les requêtes tombent en erreur CORS, ce qui se diagnostique mal
  // parce que rien ne casse au démarrage. La règle était déjà écrite dans
  // docs/deployment/mise-en-route-serveur.md ; c'est le code qui ne la tenait
  // pas. Le découpage est celui d'AppConfigService.corsOrigins, pour que la
  // garde voie exactement les valeurs que l'application utilisera.
  if (!refused.has('CORS_ORIGINS')) {
    const enClair = env.CORS_ORIGINS.split(',')
      .map((origine) => origine.trim())
      .filter((origine) => origine.length > 0 && !origine.startsWith('https://'));
    if (enClair.length > 0) {
      refuse(
        'CORS_ORIGINS',
        `chaque origine doit être en https:// en production (en clair : ${enClair.join(', ')})`,
      );
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

  // Les secrets d'exemple PUBLIÉS (`published-secrets.ts`), où qu'ils
  // apparaissent : le mot de passe PostgreSQL de développement vit au milieu
  // de DATABASE_URL. Une clé déjà refusée plus haut (S3_SECRET_ACCESS_KEY à
  // son défaut) ne reçoit pas un second message.
  for (const [key, value] of Object.entries(env as Record<string, unknown>)) {
    if (
      !refused.has(key) &&
      typeof value === 'string' &&
      PUBLISHED_DEVELOPMENT_SECRETS.some((published) => value.includes(published))
    ) {
      refuse(key, 'valeur d’exemple publiée dans le dépôt refusée en production : à remplacer');
    }
  }

  // Le coach envoie `Authorization: Bearer <clé>` et l'historique (données de
  // santé) à chaque worker (ADR 0013) : COACH_API_BASE_URL et chaque entrée
  // de COACH_WORKER_URLS. La règle est celle qu'annonce commun.conf : un
  // worker HORS du réseau compose exige https:// ET COACH_API_KEY ; un Ollama
  // interne (`http://ollama:11434/v1`) reste permis en clair, sans clé — ce
  // trafic ne quitte pas la machine.
  const workers = (env.COACH_WORKER_URLS ?? '')
    .split(',')
    .map((url) => url.trim())
    .filter((url) => url !== '');
  const targets = [
    ['COACH_API_BASE_URL', env.COACH_API_BASE_URL === undefined ? [] : [env.COACH_API_BASE_URL]],
    ['COACH_WORKER_URLS', workers],
  ] as const;
  for (const [key, urls] of targets) {
    const outside = urls.filter((url) => !isComposeService(url));
    const enClair = outside.filter((url) => !url.startsWith('https://'));
    if (enClair.length > 0) {
      refuse(
        key,
        `hors du réseau compose, chaque worker doit être en https:// en production (en clair : ${enClair.join(', ')})`,
      );
    } else if (outside.length > 0 && env.COACH_API_KEY === undefined) {
      refuse(key, 'un worker hors du réseau compose exige COACH_API_KEY en production');
    }
  }
}

/**
 * L'adresse désigne-t-elle un service du réseau compose ? Une seule étiquette
 * DNS, sans point : c'est la forme des noms de service (`ollama`,
 * `ollama-2`), que seul le DNS interne de Docker résout. Un domaine ou une
 * IPv4 ont un point, une IPv6 des crochets : ils sortent de la machine, ou
 * peuvent en sortir. `localhost` est exclu : dans le conteneur de l'API, il
 * désigne l'API elle-même — c'est la valeur de développement recopiée.
 *
 * ponytail: un nom court résolu par un domaine de recherche (resolv.conf de
 * l'hôte) passerait pour interne ; le serveur n'en déclare aucun.
 */
function isComposeService(url: string): boolean {
  try {
    const host = new URL(url).hostname.toLowerCase();
    return /^[a-z0-9][a-z0-9_-]*$/.test(host) && host !== 'localhost';
  } catch {
    // Illisible : Zod le refuse déjà ; ici, on ne le tient pas pour interne.
    return false;
  }
}
