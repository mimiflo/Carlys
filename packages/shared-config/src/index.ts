/**
 * Constantes transverses partagées entre l'API, l'admin et les outils.
 * Aucun secret ici — uniquement des valeurs publiques et structurelles.
 */

/** Préfixe global de l'API HTTP. */
export const API_GLOBAL_PREFIX = 'api';

/** Version d'API courante (préfixe d'URI : /api/v1). */
export const API_VERSION = '1';

/** En-tête de corrélation présent sur chaque requête et chaque réponse. */
export const REQUEST_ID_HEADER = 'x-request-id';

/** Pagination par défaut (pagination par curseur côté API). */
export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;

/** Limitation de débit par défaut (surchargeable par variable d'environnement). */
export const DEFAULT_RATE_LIMIT_TTL_SECONDS = 60;
export const DEFAULT_RATE_LIMIT_MAX_REQUESTS = 100;

/** Taille maximale des corps de requêtes JSON acceptés par l'API. */
export const MAX_JSON_BODY_SIZE = '1mb';
