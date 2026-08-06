import { type RequestWithId } from './request-with-id';

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
}

export function clientContextOf(request: RequestWithId): RequestClientContext {
  const userAgent = request.headers['user-agent'];
  return {
    ipAddress: request.ip,
    userAgent: typeof userAgent === 'string' ? userAgent.slice(0, 400) : undefined,
  };
}
