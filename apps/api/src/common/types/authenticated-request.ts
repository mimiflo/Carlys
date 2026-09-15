import { requestIdOf, type RequestWithId } from './request-with-id';

/** Principal attaché à la requête par le guard d'authentification. */
export interface AuthenticatedPrincipal {
  userId: string;
  sessionId: string;
}

export interface AuthenticatedRequest extends RequestWithId {
  authUser?: AuthenticatedPrincipal;
}

/** Contexte client extrait de la requête pour l'audit et les sessions. */
export interface RequestClientContext {
  ipAddress?: string;
  userAgent?: string;
  /**
   * Identifiant de corrélation de la requête.
   *
   * `AuditService` l'accepte et la colonne `AuditLog.requestId` existe, mais
   * ce contexte ne l'extrayait pas : les vingt-sept écritures d'audit qui
   * passent `...client` l'écrivaient donc TOUJOURS à `null`. Une réutilisation
   * de jeton de rafraîchissement — l'événement de sécurité qui compte le plus
   * ici — se retrouvait ainsi impossible à rapprocher des lignes Pino de la
   * requête qui l'a provoquée, alors que le dépôt pose la corrélation au
   * `requestId` comme une règle.
   */
  requestId?: string;
}

export function clientContextOf(request: RequestWithId): RequestClientContext {
  const userAgent = request.headers['user-agent'];
  return {
    ipAddress: request.ip,
    userAgent: typeof userAgent === 'string' ? userAgent.slice(0, 400) : undefined,
    requestId: requestIdOf(request),
  };
}
