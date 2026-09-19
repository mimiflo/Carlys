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
   * Ce qui a échoué, pour les JOURNAUX — pas pour le client.
   *
   * Le champ s'appelait `failureMessage` et se voulait le texte rendu à
   * l'appelant. Il ne l'atteignait jamais : `BadGatewayException` est un 502,
   * et le filtre d'exceptions remplace tout message 5xx par « Une erreur
   * interne est survenue. » — à dessein, pour ne rien laisser fuiter d'un
   * objet interne. La phrase ne servait donc à rien d'autre qu'à distinguer,
   * dans le journal d'erreur, laquelle des deux routes Stripe a échoué : le
   * paiement ou le portail. C'est utile, et c'est ce qu'elle dit maintenant.
   * Le texte montré à la personne appartient au client, qui le formule déjà.
   */
  readonly failureLog: string;
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
    throw new BadGatewayException(request.failureLog);
  }

  const payload: unknown = await response.json();
  const url =
    typeof payload === 'object' && payload !== null && 'url' in payload ? payload.url : null;
  if (typeof url !== 'string' || url === '') {
    throw new BadGatewayException(request.failureLog);
  }
  return url;
}
