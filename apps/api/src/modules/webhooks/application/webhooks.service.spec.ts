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
      upsertSubscription: jest.fn().mockResolvedValue({ id: 'sub-1', userId: USER_ID }),
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
  const logger = { error: jest.fn() };
  return new WebhooksService(
    stubs.repository as unknown as SubscriptionsRepository,
    stubs.entitlements as unknown as EntitlementsService,
    config as unknown as AppConfigService,
    logger as unknown as PinoLogger,
  );
}

function stripeBody(overrides: Record<string, unknown> = {}): Buffer {
  return Buffer.from(
    JSON.stringify({
      id: 'evt_1',
      type: 'customer.subscription.created',
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

  it('produit inconnu : échec JOURNALISÉ sur l’événement, accusé de réception quand même', async () => {
    const stubs = buildStubs();
    stubs.repository.findProduct.mockResolvedValue(null);
    const service = buildService(stubs);
    const body = stripeBody();

    const ack = await service.handleStripe(body, signedHeader(body));

    expect(ack).toEqual({ received: true });
    expect(stubs.repository.markEventFailed).toHaveBeenCalledWith(
      'event-1',
      expect.stringContaining('price_carlys_premium_monthly'),
    );
    expect(stubs.entitlements.syncFromSubscription).not.toHaveBeenCalled();
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
});
