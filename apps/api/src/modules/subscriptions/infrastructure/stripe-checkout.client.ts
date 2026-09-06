import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';
import { requestStripeUrl } from './stripe-form-request';

/**
 * Ouverture d'une session de paiement Stripe (Checkout).
 *
 * Le jour où l'on passe par les magasins d'applications (RevenueCat,
 * StoreKit), c'est un frère de ce fichier qui apparaît : le droit, lui,
 * continue d'être accordé par les webhooks, qui sont déjà idempotents et
 * signés.
 */
export interface CheckoutRequest {
  readonly userId: string;
  readonly priceId: string;
  readonly trialDays: number;
  /** Identifiant fourni par l'appareil : rejouer n'ouvre pas deux paiements. */
  readonly idempotencyKey: string;
  /**
   * Client Stripe déjà connu (`cus_…`, appris par webhook) : réutilisé plutôt
   * que recréé, pour que factures et portail de gestion restent sous un seul
   * client. Absent au premier achat.
   */
  readonly customerId?: string;
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

    // Pages RÉELLES de l'application web (apps/admin, groupe de routes
    // `(public)`) : elles invitent à revenir dans l'application et n'accordent
    // rien, le droit vient du webhook.
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
    if (request.customerId !== undefined) {
      body.set('customer', request.customerId);
    }
    if (request.trialDays > 0) {
      body.set('subscription_data[trial_period_days]', String(request.trialDays));
    }

    return requestStripeUrl({
      secret,
      endpoint: StripeCheckoutClient.endpoint,
      body,
      idempotencyKey: request.idempotencyKey,
      failureMessage: 'La page de paiement n’a pas pu être ouverte.',
    });
  }
}
