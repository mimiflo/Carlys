import { ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { createHmac } from 'node:crypto';
import { type PinoLogger } from 'nestjs-pino';
import { type AppConfigService } from '../../../config/app-config.service';
import { type EntitlementsService } from '../../subscriptions/application/entitlements.service';
import { type SubscriptionsRepository } from '../../subscriptions/infrastructure/subscriptions.repository';
import { WebhooksService } from './webhooks.service';

const SECRET = 'whsec_test_0123456789abcdef';
const USER_ID = '11111111-2222-4333-8444-555555555555';

interface Stubs {
  repository: {
    findProduct: jest.Mock;
    upsertSubscription: jest.Mock;
    recordEvent: jest.Mock;
    markEventProcessed: jest.Mock;
    markEventFailed: jest.Mock;
  };
  entitlements: { syncFromSubscription: jest.Mock };
}

function buildStubs(): Stubs {
  return {
    repository: {
      findProduct: jest.fn().mockResolvedValue({
        id: 'product-1',
        planId: 'plan-premium',
        plan: { slug: 'premium' },
      }),
      upsertSubscription: jest
        .fn()
        .mockResolvedValue({ subscription: { id: 'sub-1', userId: USER_ID }, stale: false }),
      recordEvent: jest
        .fn()
        .mockResolvedValue({ created: true, event: { id: 'event-1', processedAt: null } }),
      markEventProcessed: jest.fn().mockResolvedValue(undefined),
      markEventFailed: jest.fn().mockResolvedValue(undefined),
    },
    entitlements: { syncFromSubscription: jest.fn().mockResolvedValue(undefined) },
  };
}

function buildService(
  stubs: Stubs,
  secrets: { stripe?: string; revenueCat?: string } = { stripe: SECRET, revenueCat: SECRET },
): WebhooksService {
  const config = {
    get stripeWebhookSecret() {
      return secrets.stripe;
    },
    get revenueCatWebhookSecret() {
      return secrets.revenueCat;
    },
  };
  const logger = { error: jest.fn(), warn: jest.fn() };
  return new WebhooksService(
    stubs.repository as unknown as SubscriptionsRepository,
    stubs.entitlements as unknown as EntitlementsService,
    config as unknown as AppConfigService,
    logger as unknown as PinoLogger,
  );
}

/**
 * `created` (date d'ÉMISSION) est au niveau de l'événement, pas de l'objet :
 * le passer dans `overrides` le rendrait invisible à la garde d'ordre. D'où
 * le second paramètre.
 */
function stripeBody(overrides: Record<string, unknown> = {}, created?: number): Buffer {
  return Buffer.from(
    JSON.stringify({
      id: 'evt_1',
      type: 'customer.subscription.created',
      ...(created === undefined ? {} : { created }),
      data: {
        object: {
          id: 'sub_ext_1',
          status: 'active',
          current_period_end: 1_800_000_000,
          metadata: { userId: USER_ID },
          items: { data: [{ price: { id: 'price_carlys_premium_monthly' } }] },
          ...overrides,
        },
      },
    }),
  );
}

function signedHeader(payload: Buffer): string {
  const timestamp = Math.floor(Date.now() / 1_000);
  const signature = createHmac('sha256', SECRET)
    .update(`${timestamp}.`)
    .update(payload)
    .digest('hex');
  return `t=${timestamp},v1=${signature}`;
}

describe('WebhooksService', () => {
  it('503 tant que le secret n’est pas configuré — aucun traitement', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs, {});

    await expect(service.handleStripe(stripeBody(), 'x')).rejects.toThrow(
      ServiceUnavailableException,
    );
    expect(stubs.repository.recordEvent).not.toHaveBeenCalled();
  });

  it('signature invalide → 401, rien n’est journalisé ni traité', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await expect(service.handleStripe(stripeBody(), 't=1,v1=mauvaise')).rejects.toThrow(
      UnauthorizedException,
    );
    expect(stubs.repository.recordEvent).not.toHaveBeenCalled();
  });

  it('événement Stripe valide : projection + recalcul des entitlements', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);
    const body = stripeBody();

    const ack = await service.handleStripe(body, signedHeader(body));

    expect(ack).toEqual({ received: true });
    expect(stubs.repository.upsertSubscription).toHaveBeenCalledWith(
      expect.objectContaining({ userId: USER_ID, externalSubscriptionId: 'sub_ext_1' }),
    );
    expect(stubs.entitlements.syncFromSubscription).toHaveBeenCalled();
    expect(stubs.repository.markEventProcessed).toHaveBeenCalledWith('event-1', 'sub-1');
  });

  it('rejouer un événement déjà traité ne retraite rien (idempotence)', async () => {
    const stubs = buildStubs();
    stubs.repository.recordEvent.mockResolvedValue({
      created: false,
      event: { id: 'event-1', processedAt: new Date() },
    });
    const service = buildService(stubs);
    const body = stripeBody();

    const ack = await service.handleStripe(body, signedHeader(body));

    expect(ack).toEqual({ received: true, duplicate: true });
    expect(stubs.repository.upsertSubscription).not.toHaveBeenCalled();
  });

  it('produit inconnu : journalisé ET 503, pour que le fournisseur réémette', async () => {
    // C'est LE cas où quelqu'un a payé : un tarif créé chez Stripe avant
    // d'être chargé en base, ou une étape de catalogue ratée au déploiement.
    // Le 200 d'avant laissait ce compte gratuit pour toujours — rien ne
    // rejouait, et `processingError` n'était lu par personne.
    const stubs = buildStubs();
    stubs.repository.findProduct.mockResolvedValue(null);
    const service = buildService(stubs);
    const body = stripeBody();

    await expect(service.handleStripe(body, signedHeader(body))).rejects.toThrow(
      ServiceUnavailableException,
    );

    expect(stubs.repository.markEventFailed).toHaveBeenCalledWith(
      'event-1',
      expect.stringContaining('price_carlys_premium_monthly'),
    );
    expect(stubs.entitlements.syncFromSubscription).not.toHaveBeenCalled();
  });

  it('charge utile inexploitable : 200, car la réémettre rendrait le même échec', async () => {
    // L'autre versant de la règle, et la raison pour laquelle le 503 n'est
    // pas universel : `metadata.userId` absent n'est pas une panne
    // passagère. Stripe réémettrait le MÊME corps, trois jours durant, pour
    // rien.
    const stubs = buildStubs();
    const service = buildService(stubs);
    const body = stripeBody({ metadata: {} });

    const ack = await service.handleStripe(body, signedHeader(body));

    expect(ack).toEqual({ received: true });
    expect(stubs.repository.markEventFailed).toHaveBeenCalledWith(
      'event-1',
      expect.stringContaining('metadata.userId'),
    );
    expect(stubs.repository.upsertSubscription).not.toHaveBeenCalled();
  });

  it('la date d’ÉMISSION est transmise au dépôt, pas celle de réception', async () => {
    // Sans elle, le dépôt ne peut rien ordonner : la garde est désarmée dès
    // l'appelant. L'horodatage de la signature ne convient pas — il est
    // refait à chaque tentative d'envoi.
    const stubs = buildStubs();
    const service = buildService(stubs);
    const emission = 1_750_000_000;
    const body = stripeBody({}, emission);

    await service.handleStripe(body, signedHeader(body));

    expect(stubs.repository.upsertSubscription).toHaveBeenCalledWith(
      expect.objectContaining({ eventAt: new Date(emission * 1_000) }),
    );
  });

  it('sans date d’émission, l’événement passe : eventAt vaut null', async () => {
    // Refuser un corps sans `created` fermerait la porte à un fournisseur
    // qui ne la date pas. Faute de pouvoir comparer, on applique.
    const stubs = buildStubs();
    const service = buildService(stubs);
    const body = stripeBody();

    await service.handleStripe(body, signedHeader(body));

    expect(stubs.repository.upsertSubscription).toHaveBeenCalledWith(
      expect.objectContaining({ eventAt: null }),
    );
  });

  it('événement périmé : droits recalculés quand même, sur l’état COURANT', async () => {
    // Un événement ignoré reste un événement TRAITÉ : la ligne n'a pas
    // bougé, mais les droits se recalculent depuis elle et l'événement est
    // marqué traité — sans quoi le fournisseur le réémettrait sans fin.
    const stubs = buildStubs();
    stubs.repository.upsertSubscription.mockResolvedValue({
      subscription: { id: 'sub-1', userId: USER_ID },
      stale: true,
    });
    const service = buildService(stubs);
    const body = stripeBody({}, 1_700_000_000);

    const ack = await service.handleStripe(body, signedHeader(body));

    expect(ack).toEqual({ received: true });
    expect(stubs.entitlements.syncFromSubscription).toHaveBeenCalled();
    expect(stubs.repository.markEventProcessed).toHaveBeenCalledWith('event-1', 'sub-1');
    expect(stubs.repository.markEventFailed).not.toHaveBeenCalled();
  });

  it('RevenueCat : Bearer invalide → 401 ; EXPIRATION projette un statut expiré', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);
    const body = Buffer.from(
      JSON.stringify({
        event: {
          id: 'rc_1',
          type: 'EXPIRATION',
          app_user_id: USER_ID,
          product_id: 'carlys_premium_monthly',
          expiration_at_ms: 1_700_000_000_000,
        },
      }),
    );

    await expect(service.handleRevenueCat(body, 'Bearer mauvais-secret!')).rejects.toThrow(
      UnauthorizedException,
    );

    await service.handleRevenueCat(body, `Bearer ${SECRET}`);
    expect(stubs.repository.upsertSubscription).toHaveBeenCalledWith(
      expect.objectContaining({ userId: USER_ID, status: 'EXPIRED' }),
    );
  });

  it('RevenueCat : event_timestamp_ms sert de date d’émission', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);
    const emission = 1_755_000_000_000;
    const body = Buffer.from(
      JSON.stringify({
        event: {
          id: 'rc_2',
          type: 'RENEWAL',
          app_user_id: USER_ID,
          product_id: 'carlys_premium_monthly',
          event_timestamp_ms: emission,
        },
      }),
    );

    await service.handleRevenueCat(body, `Bearer ${SECRET}`);

    expect(stubs.repository.upsertSubscription).toHaveBeenCalledWith(
      expect.objectContaining({ eventAt: new Date(emission) }),
    );
  });
});
