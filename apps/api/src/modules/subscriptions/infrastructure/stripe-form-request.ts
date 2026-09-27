import { BadGatewayException } from '@nestjs/common';

/**
 * Le SEUL endroit du dépôt qui parle à l'API de Stripe (la vérification de
 * signature des webhooks, elle, ne l'appelle pas) : [stripeFetch] porte la
 * clé, l'idempotence et le délai ; [requestStripeUrl] en fait un `POST` en
 * formulaire dont on ne garde que l'adresse à ouvrir.
 *
 * **Sans SDK** : trois routes sont appelées (page de paiement, portail de
 * gestion, résiliation à la suppression du compte), toutes sur ce même
 * schéma. Ajouter la bibliothèque complète pour trois requêtes en formulaire
 * coûterait une dépendance de plus sans rien simplifier.
 */

/**
 * Au-delà, Stripe est tenu pour injoignable. Sans borne, une route qui
 * l'attend (la suppression d'un compte attend la résiliation) restait
 * suspendue aussi longtemps que la pile réseau le voulait.
 */
const STRIPE_TIMEOUT_MS = 10_000;

export interface StripeCall {
  readonly secret: string;
  readonly method: 'POST' | 'DELETE';
  readonly endpoint: string;
  readonly body?: URLSearchParams;
  /** Stripe garantit lui-même l'unicité sur cette clé : rejouer rend la MÊME réponse. */
  readonly idempotencyKey?: string;
}

/** Un appel à l'API de Stripe, tel quel : c'est l'appelant qui lit la réponse. */
export function stripeFetch(call: StripeCall): Promise<Response> {
  return fetch(call.endpoint, {
    method: call.method,
    headers: {
      Authorization: `Bearer ${call.secret}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      ...(call.idempotencyKey === undefined ? {} : { 'Idempotency-Key': call.idempotencyKey }),
    },
    body: call.body,
    signal: AbortSignal.timeout(STRIPE_TIMEOUT_MS),
  });
}

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
  const response = await stripeFetch({ ...request, method: 'POST' });

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
