import { BadGatewayException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';

/**
 * Ouverture d'une session de paiement Stripe.
 *
 * **Appel HTTP direct, sans SDK** : le dépôt vérifie déjà les signatures de
 * webhook à la main (`stripe-signature.util.ts`), et une seule route est
 * appelée ici. Ajouter la bibliothèque complète pour un `POST` en
 * formulaire coûterait une dépendance de plus sans rien simplifier.
 *
 * Ce fichier est le SEUL du dépôt à connaître l'API de Stripe. Le jour où
 * l'on passe par les magasins d'applications (RevenueCat, StoreKit), c'est
 * un frère de ce fichier qui apparaît : le droit, lui, continue d'être
 * accordé par les webhooks, qui sont déjà idempotents et signés.
 */
export interface CheckoutRequest {
  readonly userId: string;
  readonly priceId: string;
  readonly trialDays: number;
  /** Identifiant fourni par l'appareil : rejouer n'ouvre pas deux paiements. */
  readonly idempotencyKey: string;
}

@Injectable()
export class StripeCheckoutClient {
  constructor(private readonly config: AppConfigService) {}

  private static readonly endpoint = 'https://api.stripe.com/v1/checkout/sessions';

  /** Le paiement est-il configuré ? Sinon on ne le PROPOSE pas. */
  get isConfigured(): boolean {
    return (this.config.stripeSecretKey ?? '') !== '';
  }

  async createSession(request: CheckoutRequest): Promise<string> {
    const secret = this.config.stripeSecretKey;
    if (secret === undefined || secret === '') {
      throw new ServiceUnavailableException('Le paiement n’est pas configuré.');
    }

    const returnTo = this.config.publicAppUrl;
    const body = new URLSearchParams({
      mode: 'subscription',
      'line_items[0][price]': request.priceId,
      'line_items[0][quantity]': '1',
      success_url: `${returnTo}/abonnement/merci`,
      cancel_url: `${returnTo}/abonnement`,
      // Le rattachement de la session à l'utilisateur : c'est par lui que le
      // webhook retrouve à qui accorder le droit.
      client_reference_id: request.userId,
      'metadata[userId]': request.userId,
      'subscription_data[metadata][userId]': request.userId,
    });
    if (request.trialDays > 0) {
      body.set('subscription_data[trial_period_days]', String(request.trialDays));
    }

    const response = await fetch(StripeCheckoutClient.endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secret}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        // Stripe garantit lui-même l'unicité sur cette clé : deux appuis sur
        // le bouton rendent la MÊME page de paiement, pas deux.
        'Idempotency-Key': request.idempotencyKey,
      },
      body,
    });

    if (!response.ok) {
      // Le détail de l'erreur reste dans les journaux du fournisseur : le
      // client n'a rien à faire d'un message de Stripe, et le relayer
      // exposerait un objet interne.
      throw new BadGatewayException('La page de paiement n’a pas pu être ouverte.');
    }

    const payload: unknown = await response.json();
    const url =
      typeof payload === 'object' && payload !== null && 'url' in payload ? payload.url : null;

    if (typeof url !== 'string' || url === '') {
      throw new BadGatewayException('La page de paiement n’a pas pu être ouverte.');
    }
    return url;
  }
}
