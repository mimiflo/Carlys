import { Injectable } from '@nestjs/common';
import { AppConfigService } from '../../../config/app-config.service';
import { stripeFetch } from './stripe-form-request';

/**
 * Résiliation IMMÉDIATE d'un abonnement Stripe — celle que la suppression
 * du compte exige avant de supprimer quoi que ce soit (`AccountBillingService`).
 *
 * `DELETE /v1/subscriptions/{id}` sans paramètre : ni facture de clôture, ni
 * prorata, rien qui prélève encore. Un 404 est un SUCCÈS : Stripe ne connaît
 * plus l'abonnement, il est déjà résilié (une tentative précédente l'a fait,
 * ou la personne par le portail).
 *
 * La clé d'idempotence est celle de la TENTATIVE (`attempt`, l'identifiant
 * de la requête), comme le font les bibliothèques de Stripe : Stripe garde
 * 24 heures la première réponse d'une clé, échec compris, et une clé par
 * abonnement aurait fait rejouer un 500 à chaque nouvel essai de la
 * personne, une journée durant. D'une tentative à l'autre, l'idempotence est
 * celle de la ressource : le 404 d'un abonnement déjà résilié.
 */
@Injectable()
export class StripeSubscriptionClient {
  constructor(private readonly config: AppConfigService) {}

  private static readonly endpoint = 'https://api.stripe.com/v1/subscriptions';

  get isConfigured(): boolean {
    return (this.config.stripeSecretKey ?? '') !== '';
  }

  /** Rend quand l'abonnement ne prélève plus ; lève sinon, sans rien présumer. */
  async cancelNow(externalSubscriptionId: string, attempt: string): Promise<void> {
    const secret = this.config.stripeSecretKey;
    if (secret === undefined || secret === '') {
      throw new Error('Stripe non configuré : aucune résiliation possible.');
    }
    const response = await stripeFetch({
      secret,
      method: 'DELETE',
      endpoint: `${StripeSubscriptionClient.endpoint}/${encodeURIComponent(externalSubscriptionId)}`,
      idempotencyKey: `carlys-resiliation-${attempt}-${externalSubscriptionId}`,
    });
    if (!response.ok && response.status !== 404) {
      throw new Error(
        `Stripe : résiliation de ${externalSubscriptionId} refusée (HTTP ${response.status}).`,
      );
    }
  }
}
