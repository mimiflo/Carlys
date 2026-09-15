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
  listSubscriptions: jest.Mock;
}

function buildStubs(): Stubs {
  return {
    listEntitlements: jest.fn().mockResolvedValue([]),
    findEntitlement: jest.fn().mockResolvedValue(null),
    upsertEntitlement: jest.fn().mockResolvedValue(undefined),
    listSubscriptions: jest.fn().mockResolvedValue([]),
  };
}

/** Les arguments captés par `upsertEntitlement`, typés — `mock.calls` est `any`. */
function upsertCalls(
  stubs: Stubs,
): [string, string, { isActive: boolean; expiresAt: Date | null }][] {
  return stubs.upsertEntitlement.mock.calls as [
    string,
    string,
    { isActive: boolean; expiresAt: Date | null },
  ][];
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
    // Le plan PORTE ses droits — c'est la base qui les déclare depuis que la
    // correspondance a quitté le code (ADR 0006). Un plan sans cette liste
    // n'ouvre plus rien, et c'est voulu.
    plan: {
      id: 'plan-premium',
      slug: 'premium',
      name: 'Premium',
      entitlements: PREMIUM_ENTITLEMENT_KEYS.map((key) => ({ entitlementKey: key })),
    },
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

  describe('la correspondance plan → droits vit en BASE (ADR 0006)', () => {
    /** Un second plan payant, qui n'ouvre QUE son propre droit. */
    const PLAN_COACH = {
      id: 'plan-coach',
      slug: 'coach',
      name: 'Coach',
      entitlements: [{ entitlementKey: 'coach_dashboard' }],
    };

    it('un second plan n’écrit QUE ses droits, jamais ceux d’un autre', async () => {
      // LE DÉFAUT. Le calcul reconnaissait le plan à son slug puis réécrivait
      // la liste des droits premium codée dans les contrats. Un abonnement
      // « coach » n'étant pas « premium », `grants` valait false et la boucle
      // passait les SIX droits premium à `isActive: false` — un membre déjà
      // Premium était rétrogradé par son propre achat, en silence.
      const stubs = buildStubs();
      const service = buildService(stubs);

      await service.syncFromSubscription(
        subscriptionRow({ id: 'sub-coach', planId: 'plan-coach', plan: PLAN_COACH }),
      );

      const cles = upsertCalls(stubs).map(([, key]) => key);
      expect(cles).toEqual(['coach_dashboard']);
      expect(cles).not.toContain('premium_exercises');
    });

    it('deux plans à la fois : chacun ouvre les siens', async () => {
      const stubs = buildStubs();
      stubs.listSubscriptions.mockResolvedValue([
        subscriptionRow(),
        subscriptionRow({ id: 'sub-coach', planId: 'plan-coach', plan: PLAN_COACH }),
      ]);
      const service = buildService(stubs);

      await service.syncFromSubscription(
        subscriptionRow({ id: 'sub-coach', planId: 'plan-coach', plan: PLAN_COACH }),
      );

      const actifs = upsertCalls(stubs)
        .filter(([, , valeur]) => valeur.isActive)
        .map(([, key]) => key)
        .sort();
      expect(actifs).toEqual([...PREMIUM_ENTITLEMENT_KEYS, 'coach_dashboard'].sort());
    });

    it('un plan sans droit déclaré n’écrit RIEN — il ne révoque pas', async () => {
      // Le cas du plan `free`, et celui d'une base incomplète : ne rien
      // savoir n'autorise pas à tout couper.
      const stubs = buildStubs();
      const service = buildService(stubs);

      await service.syncFromSubscription(
        subscriptionRow({
          plan: { id: 'plan-free', slug: 'free', name: 'Gratuit', entitlements: [] },
        }),
      );

      expect(stubs.upsertEntitlement).not.toHaveBeenCalled();
    });

    it('une clé inconnue du contrat est ignorée, pas propagée', async () => {
      // La colonne est un TEXT : une ligne posée à la main peut porter
      // n'importe quoi. L'écrire ferait échouer la validation Zod de la
      // réponse — 500 sur la lecture des droits d'un compte sain.
      const stubs = buildStubs();
      const service = buildService(stubs);

      await service.syncFromSubscription(
        subscriptionRow({
          plan: {
            id: 'plan-premium',
            slug: 'premium',
            name: 'Premium',
            entitlements: [
              { entitlementKey: 'premium_exercises' },
              { entitlementKey: 'droit_qui_nexiste_pas' },
            ],
          },
        }),
      );

      expect(upsertCalls(stubs).map(([, key]) => key)).toEqual(['premium_exercises']);
    });
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

describe('syncFromSubscription — plusieurs abonnements sur un même compte', () => {
  it('un abonnement révolu NE RÉVOQUE PAS ce qu’un autre paie encore', async () => {
    // LE DÉFAUT QUE CE TEST FERME. Un compte peut légitimement porter deux
    // abonnements : la migration web → magasin d'applications, que
    // `PaymentProvider` prévoit, laisse le Stripe résilié à côté de l'achat
    // in-app actif. Le calcul se faisait depuis le SEUL abonnement reçu, puis
    // écrasait les droits du compte : l'événement terminal du révolu les
    // passait à `false` alors que l'autre, payé, les justifiait. Le membre
    // perdait son accès en ayant payé.
    const stubs = buildStubs();
    const revolu = subscriptionRow({
      id: 'sub-stripe',
      status: SubscriptionStatus.EXPIRED,
      currentPeriodEnd: PAST,
    });
    const encorePaye = subscriptionRow({
      id: 'sub-store',
      provider: 'REVENUECAT',
      status: SubscriptionStatus.ACTIVE,
      currentPeriodEnd: FUTURE,
    });
    stubs.listSubscriptions.mockResolvedValue([revolu, encorePaye]);
    const service = buildService(stubs);

    await service.syncFromSubscription(revolu);

    expect(stubs.upsertEntitlement).toHaveBeenCalledTimes(PREMIUM_ENTITLEMENT_KEYS.length);
    for (const [, , values] of upsertCalls(stubs)) {
      expect(values).toMatchObject({ isActive: true, sourceSubscriptionId: 'sub-store' });
    }
  });

  it('l’échéance retenue est la plus LOINTAINE de ceux qui ouvrent le droit', async () => {
    const stubs = buildStubs();
    const plusLoin = new Date(FUTURE.getTime() + 30 * 24 * 3_600_000);
    stubs.listSubscriptions.mockResolvedValue([
      subscriptionRow({ id: 'sub-mensuel', currentPeriodEnd: FUTURE }),
      subscriptionRow({ id: 'sub-annuel', currentPeriodEnd: plusLoin }),
    ]);
    const service = buildService(stubs);

    await service.syncFromSubscription(subscriptionRow({ id: 'sub-mensuel' }));

    for (const [, , values] of upsertCalls(stubs)) {
      expect(values).toMatchObject({ isActive: true, expiresAt: plusLoin });
    }
  });

  it('aucun abonnement ouvrant le droit : les droits tombent, comme avant', async () => {
    const stubs = buildStubs();
    const revolu = subscriptionRow({
      status: SubscriptionStatus.EXPIRED,
      currentPeriodEnd: PAST,
    });
    stubs.listSubscriptions.mockResolvedValue([revolu]);
    const service = buildService(stubs);

    await service.syncFromSubscription(revolu);

    for (const [, , values] of upsertCalls(stubs)) {
      expect(values).toMatchObject({ isActive: false });
    }
  });
});

describe('syncFromSubscription — décisions manuelles de l’administration', () => {
  it('un RETRAIT manuel survit au webhook suivant', async () => {
    // L'admin coupe l'accès d'un compte abusif : la ligne porte
    // `sourceSubscriptionId: null` et `isActive: false`, exactement comme un
    // octroi manuel porte `null` et `true`. La protection n'écoutait que les
    // octrois : un simple renouvellement rendait donc l'accès au compte que
    // l'administration venait d'écarter.
    const stubs = buildStubs();
    stubs.listEntitlements.mockResolvedValue([
      entitlementRow({ isActive: false, sourceSubscriptionId: null }),
    ]);
    stubs.listSubscriptions.mockResolvedValue([subscriptionRow()]);
    const service = buildService(stubs);

    await service.syncFromSubscription(subscriptionRow());

    const touchees = upsertCalls(stubs).map(([, key]) => key);
    expect(touchees).not.toContain('premium_exercises');
  });

  it('un OCTROI manuel survit aussi, comme avant', async () => {
    const stubs = buildStubs();
    stubs.listEntitlements.mockResolvedValue([
      entitlementRow({ isActive: true, sourceSubscriptionId: null }),
    ]);
    stubs.listSubscriptions.mockResolvedValue([
      subscriptionRow({ status: SubscriptionStatus.EXPIRED, currentPeriodEnd: PAST }),
    ]);
    const service = buildService(stubs);

    await service.syncFromSubscription(
      subscriptionRow({ status: SubscriptionStatus.EXPIRED, currentPeriodEnd: PAST }),
    );

    const touchees = upsertCalls(stubs).map(([, key]) => key);
    expect(touchees).not.toContain('premium_exercises');
  });
});
