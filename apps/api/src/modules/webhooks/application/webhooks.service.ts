import { Injectable, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { PaymentProvider, type Prisma, type SubscriptionStatus } from '@prisma/client';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { AppConfigService } from '../../../config/app-config.service';
import { AccountBillingService } from '../../subscriptions/application/account-billing.service';
import { EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { SubscriptionsRepository } from '../../subscriptions/infrastructure/subscriptions.repository';
import { UsersRepository } from '../../users/infrastructure/users.repository';
import {
  mapRevenueCatType,
  mapStripeStatus,
  namedAccount,
  UUID_PATTERN,
  type RevenueCatEvent,
  revenueCatEventSchema,
  type StripeEvent,
  stripeEventSchema,
} from './webhook-payloads';
import { PermanentWebhookError } from './webhook-errors';
import { bearerMatches, parseWebhookBody } from './webhook-request';
import { verifyStripeSignature } from './stripe-signature.util';

export interface WebhookAck {
  received: true;
  /** true : événement déjà traité — rejoué sans effet (idempotence). */
  duplicate?: true;
}

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
    private readonly users: UsersRepository,
    private readonly billing: AccountBillingService,
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

    const { json, data: event } = parseWebhookBody(rawBody, stripeEventSchema);
    if (!event.type.startsWith('customer.subscription.')) {
      return { received: true }; // Facture, paiement… : rien à projeter, rien à GARDER.
    }
    return this.ingest(
      { provider: PaymentProvider.STRIPE, externalEventId: event.id, eventType: event.type },
      json,
      namedAccount(event.data.object.metadata?.['userId']),
      () => this.projectStripe(event),
      () =>
        this.billing.stopForAbsentAccount(
          event.data.object.id,
          event.type === 'customer.subscription.deleted' ? 'canceled' : event.data.object.status,
        ),
    );
  }

  async handleRevenueCat(rawBody: Buffer, authHeader: string | undefined): Promise<WebhookAck> {
    const secret = this.config.revenueCatWebhookSecret;
    if (secret === undefined) {
      throw new ServiceUnavailableException('Webhook RevenueCat non configuré.');
    }
    if (!bearerMatches(authHeader, secret)) {
      throw new UnauthorizedException('Autorisation RevenueCat invalide.');
    }

    const { json, data: payload } = parseWebhookBody(rawBody, revenueCatEventSchema);
    const status = mapRevenueCatType(payload.event.type, payload.event.period_type);
    if (status === null) {
      return { received: true }; // Type non suivi : rien à projeter, rien à garder.
    }
    const { id: externalEventId, type: eventType } = payload.event;
    return this.ingest(
      { provider: PaymentProvider.REVENUECAT, externalEventId, eventType },
      json,
      namedAccount(payload.event.app_user_id),
      () => this.projectRevenueCat(payload, status),
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
   *
   * UN COMPTE ABSENT N'A PLUS DE WEBHOOK (acquitté, ni appliqué ni gardé :
   * après la purge, la projection violait la clé étrangère). Seul un compte
   * SUPPRIMÉ, dont la ligne existe encore, passe par `onAbsentAccount` : un
   * abonnement Stripe qui prélève est résilié
   * (`AccountBillingService.stopForAbsentAccount`). Un compte que cette base
   * ne connaît pas (sauvegarde restaurée, compte Stripe de test partagé avec
   * un autre environnement) ou déjà effacé n'est PAS résilié : la résiliation
   * est irréversible, et rien ne dit que cet abonnement est le nôtre. Ceux
   * d'un compte effacé l'ont été à sa suppression.
   */
  private async ingest(
    source: { provider: PaymentProvider; externalEventId: string; eventType: string },
    payload: unknown,
    userId: string | null,
    project: () => Promise<string>,
    onAbsentAccount: () => Promise<void> = () => Promise.resolve(),
  ): Promise<WebhookAck> {
    const { provider, externalEventId, eventType } = source;
    if (userId !== null && (await this.users.findActiveById(userId)) === null) {
      const deleted = await this.users.isDeleted(userId);
      if (deleted) {
        await onAbsentAccount();
      }
      this.logger.warn(
        { provider, externalEventId, eventType, deleted },
        'Webhook pour un compte supprimé ou inconnu — acquitté, ni appliqué ni gardé',
      );
      return { received: true };
    }
    const { created, event } = await this.subscriptions.recordEvent({
      ...source,
      payload: payload as Prisma.InputJsonValue,
      userId,
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

  private async projectStripe(event: StripeEvent): Promise<string> {
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

  private async projectRevenueCat(
    payload: RevenueCatEvent,
    status: SubscriptionStatus,
  ): Promise<string> {
    const event = payload.event;
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
}
