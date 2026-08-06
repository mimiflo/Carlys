import { type Request } from 'express';

/**
 * Requête Express enrichie par pino-http avec l'identifiant de corrélation
 * (`req.id`, typé par l'augmentation de module de pino-http).
 */
export type RequestWithId = Request;

export function requestIdOf(request: RequestWithId): string {
  const { id } = request as { id?: unknown };
  return typeof id === 'string' || typeof id === 'number' ? String(id) : 'unknown';
}
