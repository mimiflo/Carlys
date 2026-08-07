import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { PaymentProvider, type Prisma } from '@prisma/client';
import { timingSafeEqual } from 'node:crypto';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { AppConfigService } from '../../../config/app-config.service';
import { EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { SubscriptionsRepository } from '../../subscriptions/infrastructure/subscriptions.repository';
import {
  mapRevenueCatType,
  mapStripeStatus,
  type RevenueCatEvent,
  revenueCatEventSchema,
  type StripeEvent,
  stripeEventSchema,
} from './webhook-payloads';
import { verifyStripeSignature } from './stripe-signature.util';

export interface WebhookAck {
  received: true;
  /** true : événement déjà traité — rejoué sans effet (idempotence). */
  duplicate?: true;
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function secondsToDate(seconds: number | null | undefined): Date | null {
  return typeof seconds === 'number' ? new Date(seconds * 1_000) : null;
}

/**
 * Ingestion des webhooks de paiement : signature vérifiée AVANT tout
 * traitement, journal append-only (un événement n'est traité qu'une fois),
 * projection de l'état d'abonnement puis recalcul des entitlements.
 */
@Injectable()
export class WebhooksService {
  constructor(
    private readonly subscriptions: SubscriptionsRepository,
    private readonly entitlements: EntitlementsService,
    private readonly config: AppConfigService,
    @InjectPinoLogger(WebhooksService.name)
    private readonly logger: PinoLogger,
  ) {}

  async handleStripe(rawBody: Buffer, signatureHeader: string | undefined): Promise<WebhookAck> {
    const secret = this.config.stripeWebhookSecret;
    if (secret === undefined) {
      throw new ServiceUnavailableException('Webhook Stripe non configuré.');
    }
    if (!verifyStripeSignature(rawBody, signatureHeader, secret)) {
      throw new UnauthorizedException('Signature Stripe invalide.');
    }

    const { json, data: event } = this.parse(rawBody, stripeEventSchema);
    return this.ingest(PaymentProvider.STRIPE, event.id, event.type, json, () =>
      this.projectStripe(event),
    );
  }

  async handleRevenueCat(rawBody: Buffer, authHeader: string | undefined): Promise<WebhookAck> {
    const secret = this.config.revenueCatWebhookSecret;
    if (secret === undefined) {
      throw new ServiceUnavailableException('Webhook RevenueCat non configuré.');
    }
    if (!this.bearerMatches(authHeader, secret)) {
      throw new UnauthorizedException('Autorisation RevenueCat invalide.');
    }

    const { json, data: payload } = this.parse(rawBody, revenueCatEventSchema);
    return this.ingest(PaymentProvider.REVENUECAT, payload.event.id, payload.event.type, json, () =>
      this.projectRevenueCat(payload),
    );
  }

  /**
   * Journalise puis traite. Un échec de traitement est enregistré sur
   * l'événement (retraitable en rejouant le webhook) mais répond 200 :
   * le fournisseur n'a pas à réémettre un événement bien reçu.
   */
  private async ingest(
    provider: PaymentProvider,
    externalEventId: string,
    eventType: string,
    payload: unknown,
    project: () => Promise<string | null>,
  ): Promise<WebhookAck> {
    const { created, event } = await this.subscriptions.recordEvent({
      provider,
      externalEventId,
      eventType,
      payload: payload as Prisma.InputJsonValue,
    });
    if (!created && event.processedAt !== null) {
      return { received: true, duplicate: true };
    }

    try {
      const subscriptionId = await project();
      await this.subscriptions.markEventProcessed(event.id, subscriptionId);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      await this.subscriptions.markEventFailed(event.id, message);
      this.logger.error(
        { provider, externalEventId, eventType, err: error },
        'Échec de traitement du webhook — journalisé, retraitable par rejeu',
      );
    }
    return { received: true };
  }

  private async projectStripe(event: StripeEvent): Promise<string | null> {
    if (!event.type.startsWith('customer.subscription.')) {
      return null; // Événement hors abonnement : accusé de réception, rien à projeter.
    }
    const object = event.data.object;
    const userId = object.metadata?.['userId'];
    if (userId === undefined || !UUID_PATTERN.test(userId)) {
      throw new Error('metadata.userId absent ou invalide dans l’événement Stripe.');
    }
    const priceId = object.items?.data[0]?.price.id;
    if (priceId === undefined) {
      throw new Error('Aucun produit (price) dans l’événement Stripe.');
    }
    const product = await this.subscriptions.findProduct(PaymentProvider.STRIPE, priceId);
    if (product === null) {
      throw new Error(`Produit Stripe inconnu : ${priceId}.`);
    }

    const status =
      event.type === 'customer.subscription.deleted'
        ? mapStripeStatus('canceled')
        : mapStripeStatus(object.status);
    const subscription = await this.subscriptions.upsertSubscription({
      userId,
      planId: product.planId,
      provider: PaymentProvider.STRIPE,
      externalSubscriptionId: object.id,
      status,
      currentPeriodStart: secondsToDate(object.current_period_start),
      currentPeriodEnd: secondsToDate(object.current_period_end),
      cancelAtPeriodEnd: object.cancel_at_period_end ?? false,
      trialEndsAt: secondsToDate(object.trial_end),
    });
    await this.entitlements.syncFromSubscription(subscription);
    return subscription.id;
  }

  private async projectRevenueCat(payload: RevenueCatEvent): Promise<string | null> {
    const event = payload.event;
    const status = mapRevenueCatType(event.type, event.period_type);
    if (status === null) {
      return null; // Type d'événement non suivi : accusé de réception simple.
    }
    if (!UUID_PATTERN.test(event.app_user_id)) {
      throw new Error('app_user_id RevenueCat invalide (UUID utilisateur attendu).');
    }
    if (event.product_id === undefined) {
      throw new Error('product_id absent de l’événement RevenueCat.');
    }
    const product = await this.subscriptions.findProduct(
      PaymentProvider.REVENUECAT,
      event.product_id,
    );
    if (product === null) {
      throw new Error(`Produit RevenueCat inconnu : ${event.product_id}.`);
    }

    const expiresAt =
      typeof event.expiration_at_ms === 'number' ? new Date(event.expiration_at_ms) : null;
    const subscription = await this.subscriptions.upsertSubscription({
      userId: event.app_user_id,
      planId: product.planId,
      provider: PaymentProvider.REVENUECAT,
      externalSubscriptionId: event.original_transaction_id ?? event.app_user_id,
      status,
      currentPeriodStart: null,
      currentPeriodEnd: expiresAt,
      cancelAtPeriodEnd: status === 'CANCELED',
      trialEndsAt: event.period_type === 'TRIAL' ? expiresAt : null,
    });
    await this.entitlements.syncFromSubscription(subscription);
    return subscription.id;
  }

  private parse<T>(
    rawBody: Buffer,
    schema: { safeParse: (value: unknown) => { success: boolean; data?: T } },
  ): { json: unknown; data: T } {
    let json: unknown;
    try {
      json = JSON.parse(rawBody.toString('utf8'));
    } catch {
      throw new BadRequestException('Corps de webhook illisible (JSON attendu).');
    }
    const result = schema.safeParse(json);
    if (!result.success || result.data === undefined) {
      throw new BadRequestException('Charge utile de webhook invalide.');
    }
    return { json, data: result.data };
  }

  private bearerMatches(authHeader: string | undefined, secret: string): boolean {
    if (authHeader === undefined) {
      return false;
    }
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader;
    const candidate = Buffer.from(token);
    const expected = Buffer.from(secret);
    return candidate.length === expected.length && timingSafeEqual(candidate, expected);
  }
}
