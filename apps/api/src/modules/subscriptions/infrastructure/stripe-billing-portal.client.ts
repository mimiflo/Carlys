import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';
import { requestStripeUrl } from './stripe-form-request';

/**
 * Ouverture du portail de gestion Stripe (Billing Portal) : résiliation,
 * changement de moyen de paiement, factures. Même patron que la page de
 * paiement : un `POST` en formulaire, une adresse à ouvrir dans le
 * navigateur. Il faut un client Stripe, appris par webhook au premier
 * paiement.
 */
export interface BillingPortalRequest {
  readonly customerId: string;
}

@Injectable()
export class StripeBillingPortalClient {
  constructor(private readonly config: AppConfigService) {}

  private static readonly endpoint = 'https://api.stripe.com/v1/billing_portal/sessions';

  get isConfigured(): boolean {
    return (this.config.stripeSecretKey ?? '') !== '';
  }

  async createSession(request: BillingPortalRequest): Promise<string> {
    const secret = this.config.stripeSecretKey;
    if (secret === undefined || secret === '') {
      throw new ServiceUnavailableException('Le paiement n’est pas configuré.');
    }

    const body = new URLSearchParams({
      customer: request.customerId,
      // La page Abonnement de l'application web, comme l'abandon du paiement.
      return_url: `${this.config.publicAppUrl}/abonnement`,
    });

    return requestStripeUrl({
      secret,
      endpoint: StripeBillingPortalClient.endpoint,
      body,
      failureMessage: 'Le portail de gestion n’a pas pu être ouvert.',
    });
  }
}
