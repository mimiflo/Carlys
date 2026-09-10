import { type Request } from 'express';

/** Libellé unique de toutes les requêtes qui n'ont trouvé aucune route. */
export const UNMATCHED_ROUTE = '(inconnue)';

/**
 * Libellé de route pour les métriques Prometheus.
 *
 * POURQUOI PAS `req.path`. Une métrique porte une série temporelle par
 * combinaison d'étiquettes. Étiqueter avec le chemin BRUT créerait une série
 * par identifiant : `/api/v1/exercises/<uuid>` en fabriquerait autant qu'il y
 * a d'exercices, et un robot qui balaie des URL au hasard en fabriquerait
 * autant qu'il envoie de requêtes — la mémoire du processus grandirait avec
 * le trafic hostile. C'est le mode de panne classique de ce genre de mesure.
 *
 * Deux cas, deux seulement :
 *   - une route a répondu → son MOTIF (`/api/v1/exercises/:id`), dont le
 *     nombre est borné par le nombre de routes déclarées ;
 *   - aucune route n'a répondu → un libellé unique. Ne pas chercher à
 *     normaliser un chemin inconnu : la seule borne sûre est de n'en garder
 *     qu'un seul.
 */
export function routeLabel(request: Request): string {
  const pattern = matchedPattern(request);
  if (pattern === undefined) {
    return UNMATCHED_ROUTE;
  }
  // `baseUrl` est vide quand les routes sont montées à la racine (le cas de
  // Nest), et porte le préfixe quand un routeur imbriqué a servi la requête.
  const full = `${request.baseUrl}${pattern}`;
  return full.length > 1 ? full.replace(/\/+$/, '') : full;
}

/**
 * `Request.route` est typé `any` par @types/express : le routeur ne le pose
 * qu'une fois la route trouvée, et son contenu dépend de la version. On le lit
 * donc en `unknown` et on ne garde que ce dont on est sûr.
 */
function matchedPattern(request: Request): string | undefined {
  const route: unknown = request.route;
  if (typeof route !== 'object' || route === null) {
    return undefined;
  }
  const path: unknown = (route as { path?: unknown }).path;
  return typeof path === 'string' && path.length > 0 ? path : undefined;
}
