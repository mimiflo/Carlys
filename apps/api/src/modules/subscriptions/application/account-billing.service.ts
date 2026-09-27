import { Injectable } from '@nestjs/common';
import { type Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { UserFacingUnavailableException } from '../../../common/filters/user-facing-unavailable.exception';
import { AppConfigService } from '../../../config/app-config.service';
import { StripeSubscriptionClient } from '../infrastructure/stripe-subscription.client';
import { SubscriptionsRepository } from '../infrastructure/subscriptions.repository';

/** Le refus rendu à la personne quand Stripe n'a pas résilié : rien n'est supprimé. */
export const BILLING_NOT_STOPPED =
  'On n’a pas pu arrêter ton abonnement, réessaie dans un instant ; ton compte n’est pas supprimé.';

/** Statuts Stripe d'un abonnement qui ne prélèvera plus jamais. */
const STRIPE_ENDED: ReadonlySet<string> = new Set(['canceled', 'incomplete_expired']);

/** Ce que la suppression d'un compte doit arrêter chez les fournisseurs. */
export interface BillingPlan {
  /** Abonnements Stripe qui prélèvent encore : résiliés AVANT la suppression. */
  readonly stripe: ReadonlyArray<{ id: string; externalSubscriptionId: string }>;
  /**
   * Un abonnement de magasin d'applications (App Store, Play Store, via
   * RevenueCat) prélève encore. Le serveur ne peut pas le résilier : seule la
   * personne le peut, dans le magasin, et la réponse le lui dit.
   */
  readonly storeSubscriptionStillActive: boolean;
}

/**
 * SUPPRIMER SON COMPTE ARRÊTE DE PAYER.
 *
 * La suppression ne résiliait rien : Stripe continuait de prélever une
 * personne qui n'avait plus de compte, et ses webhooks étaient acquittés
 * sans effet. L'ordre est donc : résilier chez Stripe, PUIS supprimer. Si
 * Stripe ne répond pas, la suppression est REFUSÉE ([BILLING_NOT_STOPPED],
 * 503) : un compte supprimé encore prélevé est pire qu'une suppression à
 * refaire dans un instant.
 */
@Injectable()
export class AccountBillingService {
  constructor(
    private readonly subscriptions: SubscriptionsRepository,
    private readonly stripe: StripeSubscriptionClient,
    private readonly config: AppConfigService,
    @InjectPinoLogger(AccountBillingService.name)
    private readonly logger: PinoLogger,
  ) {}

  async plan(userId: string): Promise<BillingPlan> {
    const billables = await this.subscriptions.billableSubscriptions(userId);
    return {
      stripe: billables
        .filter((subscription) => subscription.provider === 'STRIPE')
        .map(({ id, externalSubscriptionId }) => ({ id, externalSubscriptionId })),
      storeSubscriptionStillActive: billables.some(
        (subscription) => subscription.provider !== 'STRIPE',
      ),
    };
  }

  /**
   * Résilie chez Stripe et rend les abonnements RÉELLEMENT arrêtés. Lève un
   * 503 écrit pour la personne si l'un d'eux ne l'est pas.
   *
   * Stripe non configuré : hors production (développement, tests), rien ne
   * peut prélever — la suppression passe, journalisée. En production, des
   * abonnements Stripe sans clé pour les résilier sont une panne de
   * configuration : refus, plutôt qu'une personne supprimée et prélevée.
   */
  async stop(plan: BillingPlan, requestId: string | undefined): Promise<string[]> {
    if (plan.stripe.length === 0) {
      return [];
    }
    if (!this.stripe.isConfigured) {
      if (this.config.isProduction) {
        this.logger.error(
          { requestId, subscriptions: plan.stripe.length },
          'Suppression de compte refusée : abonnement Stripe à résilier, Stripe non configuré',
        );
        throw new UserFacingUnavailableException(BILLING_NOT_STOPPED);
      }
      this.logger.warn(
        { requestId, subscriptions: plan.stripe.length },
        'Stripe non configuré hors production : abonnement non résilié, suppression permise',
      );
      return [];
    }
    for (const { id, externalSubscriptionId } of plan.stripe) {
      try {
        await this.stripe.cancelNow(externalSubscriptionId, requestId ?? randomUUID());
      } catch (error) {
        this.logger.error(
          { err: error, requestId, subscriptionId: id },
          'Résiliation Stripe en échec : suppression du compte refusée',
        );
        throw new UserFacingUnavailableException(BILLING_NOT_STOPPED);
      }
    }
    return plan.stripe.map(({ id }) => id);
  }

  /**
   * Un événement Stripe arrive pour un compte SUPPRIMÉ (sa ligne existe
   * encore), et son abonnement prélève encore : résilié à réception. Un
   * compte inconnu de cette base ou déjà effacé n'arrive jamais ici (voir
   * `WebhooksService.ingest`).
   *
   * La suppression résilie ce que la base CONNAÎT. Un paiement conclu juste
   * avant elle, dont le webhook arrive juste après, lui échappait : acquitté
   * sans effet, il laissait la personne supprimée prélevée chaque mois, sans
   * plus rien pour l'arrêter. Un échec de Stripe remonte : le webhook
   * répond 5xx, Stripe le réémet, la résiliation est retentée.
   */
  async stopForAbsentAccount(
    externalSubscriptionId: string,
    stripeStatus: string | undefined,
  ): Promise<void> {
    if (stripeStatus === undefined || STRIPE_ENDED.has(stripeStatus)) {
      return;
    }
    if (!this.stripe.isConfigured) {
      this.logger.error(
        { externalSubscriptionId },
        'Abonnement Stripe d’un compte supprimé : Stripe non configuré, NON résilié',
      );
      return;
    }
    // Chaque livraison du webhook est une tentative, avec sa propre clé.
    await this.stripe.cancelNow(externalSubscriptionId, randomUUID());
    this.logger.warn(
      { externalSubscriptionId },
      'Abonnement Stripe d’un compte supprimé : résilié à réception du webhook',
    );
  }

  /** DANS la transaction de suppression : ce qui est arrêté le dit en base. */
  async markStopped(ids: readonly string[], tx: Prisma.TransactionClient): Promise<void> {
    if (ids.length > 0) {
      await this.subscriptions.markCanceled(ids, tx);
    }
  }
}
