import { BadGatewayException } from '@nestjs/common';

/**
 * Le SEUL endroit du dépôt qui parle à l'API de Stripe (la vérification de
 * signature des webhooks, elle, ne l'appelle pas) : un `POST` en formulaire,
 * une réponse JSON dont on ne garde que l'adresse à ouvrir.
 *
 * **Sans SDK** : deux routes sont appelées (page de paiement, portail de
 * gestion), toutes deux sur ce même schéma. Ajouter la bibliothèque complète
 * pour deux `POST` en formulaire coûterait une dépendance de plus sans rien
 * simplifier.
 */
export interface StripeUrlRequest {
  readonly secret: string;
  readonly endpoint: string;
  readonly body: URLSearchParams;
  /** Stripe garantit lui-même l'unicité sur cette clé : rejouer rend la MÊME page. */
  readonly idempotencyKey?: string;
  /**
   * Message rendu au client en cas d'échec — jamais celui de Stripe : le
   * détail reste dans les journaux du fournisseur, et le relayer exposerait
   * un objet interne.
   */
  readonly failureMessage: string;
}

export async function requestStripeUrl(request: StripeUrlRequest): Promise<string> {
  const response = await fetch(request.endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${request.secret}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      ...(request.idempotencyKey === undefined
        ? {}
        : { 'Idempotency-Key': request.idempotencyKey }),
    },
    body: request.body,
  });

  if (!response.ok) {
    throw new BadGatewayException(request.failureMessage);
  }

  const payload: unknown = await response.json();
  const url =
    typeof payload === 'object' && payload !== null && 'url' in payload ? payload.url : null;
  if (typeof url !== 'string' || url === '') {
    throw new BadGatewayException(request.failureMessage);
  }
  return url;
}
