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
import { PermanentWebhookError } from './webhook-errors';
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
   * Journalise puis traite.
   *
   * La RÉPONSE décide de la suite : Stripe et RevenueCat réémettent tant
   * qu'ils n'ont pas reçu un 2xx. Un échec qui peut guérir tout seul répond
   * donc 5xx et sera rejoué — l'événement reste journalisé avec
   * `processedAt` à `null`, et la re-livraison le retraite, chemin déjà écrit
   * et déjà sûr. Seul un échec définitif répond 200 : voir
   * [PermanentWebhookError] pour ce que « définitif » recouvre exactement.
   *
   * L'ancienne version répondait 200 à tout, au motif que « le fournisseur
   * n'a pas à réémettre un événement bien reçu » — ce qui confond reçu et
   * APPLIQUÉ. Rien d'autre ne rejouait, et `processingError` n'était lu par
   * personne : un paiement encaissé dont la projection échouait laissait le
   * compte gratuit, définitivement et sans un mot.
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
      // Journalisé AVANT de décider de la réponse : quelle que soit la suite,
      // la cause reste lisible sur l'événement.
      await this.subscriptions.markEventFailed(event.id, message);
      if (error instanceof PermanentWebhookError) {
        this.logger.error(
          { provider, externalEventId, eventType, err: error },
          'Webhook inexploitable — journalisé, accusé de réception : le rejeu rendrait le même échec',
        );
        return { received: true };
      }
      this.logger.error(
        { provider, externalEventId, eventType, err: error },
        'Échec de traitement du webhook — 5xx rendu pour que le fournisseur réémette',
      );
      throw new ServiceUnavailableException(
        'Événement reçu mais non appliqué — réémettre (le rejeu est sans effet de bord).',
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
      throw new PermanentWebhookError(
        'metadata.userId absent ou invalide dans l’événement Stripe.',
      );
    }
    const priceId = object.items?.data[0]?.price.id;
    if (priceId === undefined) {
      throw new PermanentWebhookError('Aucun produit (price) dans l’événement Stripe.');
    }
    const product = await this.subscriptions.findProduct(PaymentProvider.STRIPE, priceId);
    if (product === null) {
      // PAS définitif, et c'est le cas dangereux : un tarif créé chez Stripe
      // avant d'être chargé en base, ou une étape de catalogue ratée au
      // déploiement. Le rejeu réussira dès que la base aura rattrapé.
      throw new Error(`Produit Stripe inconnu : ${priceId}.`);
    }

    const status =
      event.type === 'customer.subscription.deleted'
        ? mapStripeStatus('canceled')
        : mapStripeStatus(object.status);
    const { subscription, stale } = await this.subscriptions.upsertSubscription({
      userId,
      planId: product.planId,
      provider: PaymentProvider.STRIPE,
      externalSubscriptionId: object.id,
      status,
      currentPeriodStart: secondsToDate(object.current_period_start),
      currentPeriodEnd: secondsToDate(object.current_period_end),
      cancelAtPeriodEnd: object.cancel_at_period_end ?? false,
      trialEndsAt: secondsToDate(object.trial_end),
      externalCustomerId: object.customer ?? null,
      eventAt: secondsToDate(event.created),
    });
    this.logIfStale(stale, PaymentProvider.STRIPE, event.id, subscription.id);
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
      throw new PermanentWebhookError(
        'app_user_id RevenueCat invalide (UUID utilisateur attendu).',
      );
    }
    if (event.product_id === undefined) {
      throw new PermanentWebhookError('product_id absent de l’événement RevenueCat.');
    }
    const product = await this.subscriptions.findProduct(
      PaymentProvider.REVENUECAT,
      event.product_id,
    );
    if (product === null) {
      // Rattrapable, comme côté Stripe : le catalogue peut rattraper.
      throw new Error(`Produit RevenueCat inconnu : ${event.product_id}.`);
    }

    const expiresAt =
      typeof event.expiration_at_ms === 'number' ? new Date(event.expiration_at_ms) : null;
    const { subscription, stale } = await this.subscriptions.upsertSubscription({
      userId: event.app_user_id,
      planId: product.planId,
      provider: PaymentProvider.REVENUECAT,
      externalSubscriptionId: event.original_transaction_id ?? event.app_user_id,
      status,
      currentPeriodStart: null,
      currentPeriodEnd: expiresAt,
      cancelAtPeriodEnd: status === 'CANCELED',
      trialEndsAt: event.period_type === 'TRIAL' ? expiresAt : null,
      // Les magasins n'ont pas de portail Stripe : rien à retenir ici.
      externalCustomerId: null,
      eventAt:
        typeof event.event_timestamp_ms === 'number' ? new Date(event.event_timestamp_ms) : null,
    });
    this.logIfStale(stale, PaymentProvider.REVENUECAT, event.id, subscription.id);
    await this.entitlements.syncFromSubscription(subscription);
    return subscription.id;
  }

  /**
   * Un événement périmé n'est ni une erreur ni un silence : il est TRACÉ.
   * Sans cette ligne, une inversion d'ordre répétée — signe d'un vrai
   * problème chez le fournisseur ou d'un réessai en boucle — resterait
   * invisible, la garde faisant simplement son office sans le dire.
   */
  private logIfStale(
    stale: boolean,
    provider: PaymentProvider,
    externalEventId: string,
    subscriptionId: string,
  ): void {
    if (!stale) {
      return;
    }
    this.logger.warn(
      { provider, externalEventId, subscriptionId },
      'Webhook plus ancien que le dernier appliqué — ignoré, droits recalculés sur l’état courant',
    );
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
