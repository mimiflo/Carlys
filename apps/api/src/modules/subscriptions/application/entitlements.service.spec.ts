import { PREMIUM_ENTITLEMENT_KEYS } from '@carlys/api-contracts';
import { SubscriptionStatus } from '@prisma/client';
import { type SubscriptionsRepository } from '../infrastructure/subscriptions.repository';
import { EntitlementsService, subscriptionGrantsAccess } from './entitlements.service';

const USER = 'user-1';
const FUTURE = new Date(Date.now() + 7 * 24 * 3_600_000);
const PAST = new Date(Date.now() - 24 * 3_600_000);

interface Stubs {
  listEntitlements: jest.Mock;
  findEntitlement: jest.Mock;
  upsertEntitlement: jest.Mock;
}

function buildStubs(): Stubs {
  return {
    listEntitlements: jest.fn().mockResolvedValue([]),
    findEntitlement: jest.fn().mockResolvedValue(null),
    upsertEntitlement: jest.fn().mockResolvedValue(undefined),
  };
}

function buildService(stubs: Stubs): EntitlementsService {
  return new EntitlementsService(stubs as unknown as SubscriptionsRepository);
}

function entitlementRow(overrides: Record<string, unknown> = {}): unknown {
  return {
    id: 'ent-1',
    userId: USER,
    entitlementKey: 'premium_exercises',
    isActive: true,
    expiresAt: null,
    sourceSubscriptionId: 'sub-1',
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

function subscriptionRow(overrides: Record<string, unknown> = {}): never {
  return {
    id: 'sub-1',
    userId: USER,
    planId: 'plan-premium',
    provider: 'STRIPE',
    externalSubscriptionId: 'sub_ext',
    status: SubscriptionStatus.ACTIVE,
    currentPeriodStart: PAST,
    currentPeriodEnd: FUTURE,
    cancelAtPeriodEnd: false,
    trialEndsAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    plan: { id: 'plan-premium', slug: 'premium', name: 'Premium' },
    ...overrides,
  } as never;
}

describe('subscriptionGrantsAccess', () => {
  const now = Date.now();

  it('TRIALING et ACTIVE donnent accès', () => {
    expect(subscriptionGrantsAccess(SubscriptionStatus.TRIALING, null, now)).toBe(true);
    expect(subscriptionGrantsAccess(SubscriptionStatus.ACTIVE, null, now)).toBe(true);
  });

  it('PAST_DUE et CANCELED donnent accès jusqu’à la fin de période payée', () => {
    expect(subscriptionGrantsAccess(SubscriptionStatus.PAST_DUE, FUTURE, now)).toBe(true);
    expect(subscriptionGrantsAccess(SubscriptionStatus.CANCELED, FUTURE, now)).toBe(true);
    expect(subscriptionGrantsAccess(SubscriptionStatus.PAST_DUE, PAST, now)).toBe(false);
    expect(subscriptionGrantsAccess(SubscriptionStatus.CANCELED, null, now)).toBe(false);
  });

  it('EXPIRED ne donne jamais accès', () => {
    expect(subscriptionGrantsAccess(SubscriptionStatus.EXPIRED, FUTURE, now)).toBe(false);
  });
});

describe('EntitlementsService', () => {
  it('un droit expiré est inactif à la lecture, même si isActive est vrai en base', async () => {
    const stubs = buildStubs();
    stubs.findEntitlement.mockResolvedValue(entitlementRow({ expiresAt: PAST }));
    const service = buildService(stubs);

    await expect(service.hasEntitlement(USER, 'premium_exercises')).resolves.toBe(false);
  });

  it('entitlementsFor sert toutes les clés réservées, actives ou non', async () => {
    const stubs = buildStubs();
    stubs.listEntitlements.mockResolvedValue([entitlementRow()]);
    const service = buildService(stubs);

    const response = await service.entitlementsFor(USER);

    expect(response.isPremium).toBe(true);
    expect(response.planSlug).toBe('premium');
    expect(response.entitlements.length).toBeGreaterThanOrEqual(9);
    expect(
      response.entitlements.find((entitlement) => entitlement.key === 'ai_coaching')?.isActive,
    ).toBe(false);
  });

  it('syncFromSubscription matérialise les droits premium', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.syncFromSubscription(subscriptionRow());

    expect(stubs.upsertEntitlement).toHaveBeenCalledTimes(PREMIUM_ENTITLEMENT_KEYS.length);
    expect(stubs.upsertEntitlement).toHaveBeenCalledWith(
      USER,
      'premium_exercises',
      expect.objectContaining({ isActive: true, sourceSubscriptionId: 'sub-1' }),
    );
  });

  it('un abonnement expiré révoque les droits synchronisés', async () => {
    const stubs = buildStubs();
    const service = buildService(stubs);

    await service.syncFromSubscription(
      subscriptionRow({ status: SubscriptionStatus.EXPIRED, currentPeriodEnd: PAST }),
    );

    expect(stubs.upsertEntitlement).toHaveBeenCalledWith(
      USER,
      'premium_exercises',
      expect.objectContaining({ isActive: false }),
    );
  });

  it('les attributions manuelles actives ne sont jamais écrasées', async () => {
    const stubs = buildStubs();
    stubs.listEntitlements.mockResolvedValue([
      entitlementRow({ entitlementKey: 'premium_exercises', sourceSubscriptionId: null }),
    ]);
    const service = buildService(stubs);

    await service.syncFromSubscription(
      subscriptionRow({ status: SubscriptionStatus.EXPIRED, currentPeriodEnd: PAST }),
    );

    const touchedKeys = stubs.upsertEntitlement.mock.calls.map((call: unknown[]) => call[1]);
    expect(touchedKeys).not.toContain('premium_exercises');
  });
});
