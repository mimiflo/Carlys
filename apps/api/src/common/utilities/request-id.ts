import { REQUEST_ID_HEADER } from '@carlys/shared-config';
import { randomUUID } from 'node:crypto';
import { type IncomingMessage, type ServerResponse } from 'node:http';

const REQUEST_ID_PATTERN = /^[\w-]{1,64}$/;

/**
 * L'identifiant de corrélation d'une requête : l'en-tête `x-request-id`
 * entrant s'il est sûr ([\w-]{1,64}), sinon un UUID. Il est renvoyé sur la
 * réponse. Un identifiant déjà posé (`req.id`) est repris tel quel : une
 * requête n'en porte jamais deux.
 */
export function generateRequestId(request: IncomingMessage, response: ServerResponse): string {
  const posed = (request as { id?: unknown }).id;
  if (typeof posed === 'string') {
    return posed;
  }
  const incoming = request.headers[REQUEST_ID_HEADER];
  const requestId =
    typeof incoming === 'string' && REQUEST_ID_PATTERN.test(incoming) ? incoming : randomUUID();
  response.setHeader(REQUEST_ID_HEADER, requestId);
  return requestId;
}

/**
 * Pose `req.id` AVANT tout autre intergiciel.
 *
 * POURQUOI ICI ET PAS SEULEMENT DANS PINO-HTTP. pino-http est un intergiciel
 * de MODULE : Nest l'enregistre à l'initialisation, donc APRÈS les parseurs
 * de corps que pose `configureApp`. Une requête refusée par un parseur (JSON
 * malformé, corps trop lourd) n'atteignait jamais pino-http : sa réponse
 * d'erreur portait `requestId: "unknown"` et aucun en-tête `x-request-id`,
 * et rien ne permettait de la retrouver dans les journaux. pino-http reprend
 * `req.id` quand il existe (`req.id = req.id || genReqId(…)`) : l'identifiant
 * est le même d'un bout à l'autre.
 */
export function requestIdMiddleware(
  request: IncomingMessage,
  response: ServerResponse,
  next: () => void,
): void {
  (request as { id?: string }).id = generateRequestId(request, response);
  next();
}
