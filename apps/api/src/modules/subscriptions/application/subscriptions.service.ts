import {
  type BillingPortalSession,
  type CheckoutSession,
  type Subscription as SubscriptionContract,
  type SubscriptionMe,
  type SubscriptionOffersResponse,
  subscriptionPlanSlugSchema,
} from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { EntitlementsService } from './entitlements.service';
import { MONTHLY_OFFER_ID, YEARLY_OFFER_ID, buildOfferCatalog } from './subscription-offers';
import { AppConfigService } from '../../../config/app-config.service';
import {
  SubscriptionsRepository,
  type SubscriptionWithPlan,
} from '../infrastructure/subscriptions.repository';
import { StripeBillingPortalClient } from '../infrastructure/stripe-billing-portal.client';
import { StripeCheckoutClient } from '../infrastructure/stripe-checkout.client';

function presentSubscription(subscription: SubscriptionWithPlan): SubscriptionContract {
  const planSlug = subscriptionPlanSlugSchema.safeParse(subscription.plan.slug);
  return {
    id: subscription.id,
    planSlug: planSlug.success ? planSlug.data : 'free',
    planName: subscription.plan.name,
    provider: subscription.provider,
    status: subscription.status,
    currentPeriodStart: subscription.currentPeriodStart?.toISOString() ?? null,
    currentPeriodEnd: subscription.currentPeriodEnd?.toISOString() ?? null,
    cancelAtPeriodEnd: subscription.cancelAtPeriodEnd,
    trialEndsAt: subscription.trialEndsAt?.toISOString() ?? null,
  };
}

@Injectable()
export class SubscriptionsService {
  constructor(
    private readonly subscriptions: SubscriptionsRepository,
    private readonly entitlements: EntitlementsService,
    private readonly config: AppConfigService,
    private readonly checkout: StripeCheckoutClient,
    private readonly portal: StripeBillingPortalClient,
  ) {}

  /** Plan effectif — décidé côté serveur, le client ne fait qu'afficher. */
  async me(userId: string): Promise<SubscriptionMe> {
    const [subscription, isPremium] = await Promise.all([
      this.subscriptions.latestSubscription(userId),
      this.entitlements.hasEntitlement(userId, 'premium_exercises'),
    ]);

    return {
      planSlug: isPremium ? 'premium' : 'free',
      planName: isPremium ? 'Premium' : 'Gratuit',
      isPremium,
      subscription: subscription === null ? null : presentSubscription(subscription),
    };
  }

  /**
   * Le catalogue. Il reste lisible même sans paiement configuré : montrer ce
   * que Premium apporte a du sens en soi, promettre un achat qui échouerait
   * n'en a aucun.
   */
  offers(): SubscriptionOffersResponse {
    return {
      offers: buildOfferCatalog({
        currency: this.config.subscriptionCurrency,
        monthlyCents: this.config.subscriptionMonthlyCents,
        yearlyCents: this.config.subscriptionYearlyCents,
        trialDays: this.config.subscriptionTrialDays,
      }),
      checkoutAvailable: this.checkout.isConfigured && this.hasPricesConfigured(),
    };
  }

  /**
   * Ouvre une page de paiement pour une offre.
   *
   * Aucun droit n'est accordé ici, et c'est essentiel : c'est le WEBHOOK
   * signé qui l'accorde, une fois le paiement réellement encaissé. Une
   * application qui s'octroierait Premium au retour de la page de paiement
   * suffirait à contourner la caisse.
   *
   * Un client Stripe déjà connu (abonnement passé, appris par webhook) est
   * réutilisé : factures et portail de gestion restent sous un seul client.
   */
  async createCheckout(userId: string, offerId: string, id: string): Promise<CheckoutSession> {
    const priceId = this.priceFor(offerId);
    if (priceId === undefined) {
      throw new BadRequestException('Offre inconnue.');
    }
    if (!this.checkout.isConfigured) {
      throw new ServiceUnavailableException('Le paiement n’est pas configuré.');
    }

    const customerId = await this.subscriptions.stripeCustomerIdOf(userId);
    const url = await this.checkout.createSession({
      userId,
      priceId,
      trialDays: this.config.subscriptionTrialDays,
      idempotencyKey: id,
      ...(customerId === null ? {} : { customerId }),
    });
    return { url, provider: 'STRIPE' };
  }

  /**
   * Portail de gestion Stripe : résiliation, moyen de paiement, factures.
   * Il faut un client Stripe, appris par webhook au premier paiement : sans
   * lui il n'y a rien à gérer (compte gratuit, ou abonnement passé par un
   * magasin d'applications), c'est un conflit d'état (409), pas une panne.
   */
  async createPortal(userId: string): Promise<BillingPortalSession> {
    const customerId = await this.subscriptions.stripeCustomerIdOf(userId);
    if (customerId === null) {
      throw new ConflictException('Aucun abonnement Stripe à gérer.');
    }
    if (!this.portal.isConfigured) {
      throw new ServiceUnavailableException('Le paiement n’est pas configuré.');
    }
    return { url: await this.portal.createSession({ customerId }) };
  }

  private priceFor(offerId: string): string | undefined {
    const price =
      offerId === MONTHLY_OFFER_ID
        ? this.config.stripePriceMonthly
        : offerId === YEARLY_OFFER_ID
          ? this.config.stripePriceYearly
          : undefined;
    return price === '' ? undefined : price;
  }

  private hasPricesConfigured(): boolean {
    return (
      this.priceFor(MONTHLY_OFFER_ID) !== undefined || this.priceFor(YEARLY_OFFER_ID) !== undefined
    );
  }
}
