import {
  BadRequestException,
  ConflictException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { type AppConfigService } from '../../../config/app-config.service';
import { type StripeBillingPortalClient } from '../infrastructure/stripe-billing-portal.client';
import { type StripeCheckoutClient } from '../infrastructure/stripe-checkout.client';
import { type SubscriptionsRepository } from '../infrastructure/subscriptions.repository';
import { type EntitlementsService } from './entitlements.service';
import { MONTHLY_OFFER_ID, YEARLY_OFFER_ID } from './subscription-offers';
import { SubscriptionsService } from './subscriptions.service';

const USER = 'utilisateur-1';
/** Identifiant engendré par l'appareil : la clé d'idempotence du paiement. */
const DEVICE_ID = '11111111-1111-4111-8111-111111111111';
const SESSION_URL = 'https://checkout.stripe.com/c/pay/cs_test_123';

interface ConfigStub {
  subscriptionCurrency: string;
  subscriptionMonthlyCents: number;
  subscriptionYearlyCents: number;
  subscriptionTrialDays: number;
  stripePriceMonthly: string | undefined;
  stripePriceYearly: string | undefined;
}

function buildConfig(overrides: Partial<ConfigStub> = {}): ConfigStub {
  return {
    subscriptionCurrency: 'EUR',
    subscriptionMonthlyCents: 999,
    subscriptionYearlyCents: 7990,
    subscriptionTrialDays: 7,
    stripePriceMonthly: 'price_mensuel',
    stripePriceYearly: 'price_annuel',
    ...overrides,
  };
}

interface CheckoutStub {
  isConfigured: boolean;
  createSession: jest.Mock;
}

function buildCheckout(configured = true): CheckoutStub {
  return { isConfigured: configured, createSession: jest.fn().mockResolvedValue(SESSION_URL) };
}

const PORTAL_URL = 'https://billing.stripe.com/p/session/test_123';
const CUSTOMER_ID = 'cus_connu';

interface PortalStub {
  isConfigured: boolean;
  createSession: jest.Mock;
}

function buildPortal(configured = true): PortalStub {
  return { isConfigured: configured, createSession: jest.fn().mockResolvedValue(PORTAL_URL) };
}

const repositoryStub = {
  latestSubscription: jest.fn().mockResolvedValue(null),
  // Par défaut, aucun client Stripe connu : premier achat.
  stripeCustomerIdOf: jest.fn().mockResolvedValue(null),
};
const entitlementsStub = { hasEntitlement: jest.fn().mockResolvedValue(false) };

function buildService(
  config: ConfigStub,
  checkout: CheckoutStub,
  portal: PortalStub = buildPortal(),
): SubscriptionsService {
  return new SubscriptionsService(
    repositoryStub as unknown as SubscriptionsRepository,
    entitlementsStub as unknown as EntitlementsService,
    config as unknown as AppConfigService,
    checkout as unknown as StripeCheckoutClient,
    portal as unknown as StripeBillingPortalClient,
  );
}

beforeEach(() => {
  repositoryStub.latestSubscription.mockClear();
  repositoryStub.stripeCustomerIdOf.mockReset().mockResolvedValue(null);
  entitlementsStub.hasEntitlement.mockClear();
});

describe('SubscriptionsService — chemin d’achat', () => {
  it('ouvre une page pour l’offre mensuelle, l’identifiant appareil servant de clé d’idempotence', async () => {
    const checkout = buildCheckout();
    const service = buildService(buildConfig(), checkout);

    const session = await service.createCheckout(USER, MONTHLY_OFFER_ID, DEVICE_ID);

    expect(session).toEqual({ url: SESSION_URL, provider: 'STRIPE' });
    expect(checkout.createSession).toHaveBeenCalledWith({
      userId: USER,
      priceId: 'price_mensuel',
      trialDays: 7,
      idempotencyKey: DEVICE_ID,
    });
  });

  it('l’offre annuelle mène à SON prix Stripe', async () => {
    const checkout = buildCheckout();
    await buildService(buildConfig(), checkout).createCheckout(USER, YEARLY_OFFER_ID, DEVICE_ID);

    expect(checkout.createSession).toHaveBeenCalledWith(
      expect.objectContaining({ priceId: 'price_annuel' }),
    );
  });

  it('une offre inconnue est refusée (400) sans le moindre appel à Stripe', async () => {
    const checkout = buildCheckout();
    await expect(
      buildService(buildConfig(), checkout).createCheckout(USER, 'offre-fantome', DEVICE_ID),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(checkout.createSession).not.toHaveBeenCalled();
  });

  it('une offre connue mais sans prix configuré est traitée comme inconnue', async () => {
    const checkout = buildCheckout();
    const service = buildService(buildConfig({ stripePriceYearly: undefined }), checkout);

    await expect(service.createCheckout(USER, YEARLY_OFFER_ID, DEVICE_ID)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    // Le mensuel, lui, reste achetable.
    await expect(service.createCheckout(USER, MONTHLY_OFFER_ID, DEVICE_ID)).resolves.toBeDefined();
  });

  it('paiement non configuré : 503, sans appel', async () => {
    const checkout = buildCheckout(false);
    await expect(
      buildService(buildConfig(), checkout).createCheckout(USER, MONTHLY_OFFER_ID, DEVICE_ID),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(checkout.createSession).not.toHaveBeenCalled();
  });

  it('n’accorde AUCUN droit : ni le dépôt ni les entitlements ne sont touchés', async () => {
    await buildService(buildConfig(), buildCheckout()).createCheckout(
      USER,
      MONTHLY_OFFER_ID,
      DEVICE_ID,
    );

    expect(repositoryStub.latestSubscription).not.toHaveBeenCalled();
    expect(entitlementsStub.hasEntitlement).not.toHaveBeenCalled();
  });

  it('au premier achat, aucun client n’est passé : Stripe le crée', async () => {
    const checkout = buildCheckout();
    await buildService(buildConfig(), checkout).createCheckout(USER, MONTHLY_OFFER_ID, DEVICE_ID);

    const [firstRequest] = checkout.createSession.mock.calls[0] as [Record<string, unknown>];
    expect(firstRequest).not.toHaveProperty('customerId');
  });

  it('un client Stripe déjà connu (appris par webhook) est réutilisé, jamais recréé', async () => {
    repositoryStub.stripeCustomerIdOf.mockResolvedValue(CUSTOMER_ID);
    const checkout = buildCheckout();

    await buildService(buildConfig(), checkout).createCheckout(USER, MONTHLY_OFFER_ID, DEVICE_ID);

    expect(repositoryStub.stripeCustomerIdOf).toHaveBeenCalledWith(USER);
    expect(checkout.createSession).toHaveBeenCalledWith(
      expect.objectContaining({ customerId: CUSTOMER_ID }),
    );
  });

  it('une erreur du client Stripe remonte telle quelle : rien n’est masqué en succès', async () => {
    const checkout = buildCheckout();
    checkout.createSession.mockRejectedValue(new Error('Stripe indisponible'));

    await expect(
      buildService(buildConfig(), checkout).createCheckout(USER, MONTHLY_OFFER_ID, DEVICE_ID),
    ).rejects.toThrow('Stripe indisponible');
  });
});

describe('SubscriptionsService — portail de gestion', () => {
  it('sans client Stripe connu : 409, il n’y a rien à gérer, sans appel', async () => {
    const portal = buildPortal();
    await expect(
      buildService(buildConfig(), buildCheckout(), portal).createPortal(USER),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(portal.createSession).not.toHaveBeenCalled();
  });

  it('le 409 prime sur la configuration : sans client, pas de 503 trompeur', async () => {
    const portal = buildPortal(false);
    await expect(
      buildService(buildConfig(), buildCheckout(), portal).createPortal(USER),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('client connu mais paiement non configuré : 503', async () => {
    repositoryStub.stripeCustomerIdOf.mockResolvedValue(CUSTOMER_ID);
    const portal = buildPortal(false);

    await expect(
      buildService(buildConfig(), buildCheckout(), portal).createPortal(USER),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(portal.createSession).not.toHaveBeenCalled();
  });

  it('client connu : le portail s’ouvre pour LUI et la réponse ne porte que l’adresse', async () => {
    repositoryStub.stripeCustomerIdOf.mockResolvedValue(CUSTOMER_ID);
    const portal = buildPortal();

    const session = await buildService(buildConfig(), buildCheckout(), portal).createPortal(USER);

    expect(session).toEqual({ url: PORTAL_URL });
    expect(portal.createSession).toHaveBeenCalledWith({ customerId: CUSTOMER_ID });
  });
});

describe('SubscriptionsService — catalogue', () => {
  it('n’annonce l’achat que si la clé ET au moins un prix sont configurés', () => {
    expect(buildService(buildConfig(), buildCheckout()).offers().checkoutAvailable).toBe(true);
    expect(buildService(buildConfig(), buildCheckout(false)).offers().checkoutAvailable).toBe(
      false,
    );
    expect(
      buildService(
        buildConfig({ stripePriceMonthly: undefined, stripePriceYearly: undefined }),
        buildCheckout(),
      ).offers().checkoutAvailable,
    ).toBe(false);
  });

  it('le catalogue reste lisible sans paiement configuré', () => {
    const { offers } = buildService(buildConfig(), buildCheckout(false)).offers();
    expect(offers.map((offer) => offer.id)).toEqual([MONTHLY_OFFER_ID, YEARLY_OFFER_ID]);
  });
});
