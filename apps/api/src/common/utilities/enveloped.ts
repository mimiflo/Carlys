import { type ApiSuccessEnvelope } from '@carlys/api-contracts';
import { requestIdOf, type RequestWithId } from '../types/request-with-id';

/**
 * Construit explicitement l'enveloppe de succès quand un handler doit fournir
 * des métadonnées (pagination…) — l'intercepteur global la laisse alors telle
 * quelle.
 */
export function enveloped<TData, TMeta extends object>(
  data: TData,
  meta: TMeta,
  request: RequestWithId,
): ApiSuccessEnvelope<TData, TMeta> {
  return { data, meta, requestId: requestIdOf(request) };
}
