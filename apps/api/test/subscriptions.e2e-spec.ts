process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';
process.env.STRIPE_WEBHOOK_SECRET ??= 'whsec_e2e_stripe_0123456789';
process.env.REVENUECAT_WEBHOOK_SECRET ??= 'rcsec_e2e_revenuecat_0123456789';
// Clé et prix FACTICES : le client Stripe est remplacé par un faux dans le
// module de test, aucun appel réseau ne part jamais.
process.env.STRIPE_SECRET_KEY ??= 'sk_test_e2e_0123456789abcdef';
process.env.STRIPE_PRICE_MONTHLY ??= 'price_carlys_premium_monthly';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type CheckoutSession,
  type EntitlementsResponse,
  type SubscriptionMe,
  type SubscriptionOffersResponse,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PaymentProvider, PrismaClient } from '@prisma/client';
import { createHmac, randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { MONTHLY_OFFER_ID } from '../src/modules/subscriptions/application/subscription-offers';
import {
  type CheckoutRequest,
  StripeCheckoutClient,
} from '../src/modules/subscriptions/infrastructure/stripe-checkout.client';
import { ensureExerciseFixture } from './support/exercise-fixture';

const STRIPE_SECRET = process.env.STRIPE_WEBHOOK_SECRET;
const REVENUECAT_SECRET = process.env.REVENUECAT_WEBHOOK_SECRET;

/**
 * Abonnements : webhooks SIGNÉS et IDEMPOTENTS, entitlements décidés côté
 * serveur, accès premium appliqué sur le catalogue, chemin d'achat avec un
 * client Stripe FACTICE (aucune clé réelle, aucun appel réseau).
 */
describe('Abonnements (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let accessToken: string;
  let userId: string;
  let rcAccessToken: string;
  let rcUserId: string;
  let premiumExerciseSlug: string;
  const userEmail = `e2e-abonnements-${randomUUID()}@carlys.test`;
  const rcEmail = `e2e-abonnements-rc-${randomUUID()}@carlys.test`;

  const eventPrefix = `evt-e2e-${randomUUID()}`;
  const stripeSubscriptionId = `sub_e2e_${randomUUID()}`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

  const stripeSign = (payload: string): string => {
    const timestamp = Math.floor(Date.now() / 1_000);
    const signature = createHmac('sha256', STRIPE_SECRET)
      .update(`${timestamp}.${payload}`)
      .digest('hex');
    return `t=${timestamp},v1=${signature}`;
  };

  const postStripe = (payload: string, header?: string) =>
    request(app.getHttpServer())
      .post('/api/v1/webhooks/stripe')
      .set('Content-Type', 'application/json')
      .set('Stripe-Signature', header ?? stripeSign(payload))
      .send(payload);

  const stripeEvent = (eventId: string, type: string, object: Record<string, unknown>): string =>
    JSON.stringify({
      id: eventId,
      type,
      data: {
        object: {
          id: stripeSubscriptionId,
          metadata: { userId },
          items: { data: [{ price: { id: 'price_carlys_premium_monthly' } }] },
          ...object,
        },
      },
    });

  const authed = (token: string) => ({
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${token}`),
  });

  /** Le faux client Stripe : il se souvient de chaque session demandée. */
  const checkoutCalls: CheckoutRequest[] = [];
  const fakeCheckout: Pick<StripeCheckoutClient, 'isConfigured' | 'createSession'> = {
    isConfigured: true,
    createSession: (checkout) => {
      checkoutCalls.push(checkout);
      return Promise.resolve(`https://checkout.stripe.test/${checkout.idempotencyKey}`);
    },
  };

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(StripeCheckoutClient)
      .useValue(fakeCheckout)
      .compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const register = async (email: string) => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ email, password: 'MotDePasseSolide42', displayName: 'E2E' })
        .expect(201);
      return data<AuthResult>(response.body);
    };
    const first = await register(userEmail);
    accessToken = first.tokens.accessToken;
    userId = first.user.id;
    const second = await register(rcEmail);
    rcAccessToken = second.tokens.accessToken;
    rcUserId = second.user.id;

    // Fixtures du catalogue de plans (déjà présentes via le seed ; upsert
    // idempotent pour rendre la suite autonome).
    const plan = await prisma.subscriptionPlan.upsert({
      where: { slug: 'premium' },
      update: {},
      create: { slug: 'premium', name: 'Premium' },
    });
    for (const [provider, externalProductId] of [
      [PaymentProvider.STRIPE, 'price_carlys_premium_monthly'],
      [PaymentProvider.REVENUECAT, 'carlys_premium_monthly'],
    ] as const) {
      await prisma.subscriptionProduct.upsert({
        where: { provider_externalProductId: { provider, externalProductId } },
        update: {},
        create: {
          planId: plan.id,
          provider,
          externalProductId,
          billingPeriod: 'MONTHLY',
        },
      });
    }

    // Fixture dédiée : la suite ne dépend jamais du seed (base CI vierge).
    const premiumExercise = await ensureExerciseFixture(prisma, 'e2e-subs-premium', {
      isPremium: true,
    });
    premiumExerciseSlug = premiumExercise.slug;
  });

  afterAll(async () => {
    // Nettoyage strictement limité à cette suite (les e2e partagent la base).
    await prisma.subscriptionEvent.deleteMany({
      where: { externalEventId: { startsWith: eventPrefix } },
    });
    await prisma.user.deleteMany({ where: { email: { in: [userEmail, rcEmail] } } });
    await prisma.exercise.deleteMany({ where: { slug: 'e2e-subs-premium' } });
    await prisma.$disconnect();
    await app.close();
  });

  it('un nouveau compte est au plan gratuit, sans aucun droit premium', async () => {
    const me = data<SubscriptionMe>(
      (await authed(accessToken).get('/api/v1/subscriptions/me').expect(200)).body,
    );
    expect(me.planSlug).toBe('free');
    expect(me.isPremium).toBe(false);
    expect(me.subscription).toBeNull();

    const entitlements = data<EntitlementsResponse>(
      (await authed(accessToken).get('/api/v1/entitlements').expect(200)).body,
    );
    expect(entitlements.entitlements.every((entitlement) => !entitlement.isActive)).toBe(true);

    await request(app.getHttpServer()).get('/api/v1/entitlements').expect(401);
  });

  it('un exercice premium du catalogue est refusé au plan gratuit (403)', async () => {
    await authed(accessToken).get(`/api/v1/exercises/${premiumExerciseSlug}`).expect(403);
  });

  it('refuse un webhook Stripe non signé ou mal signé — rien n’est traité', async () => {
    const payload = stripeEvent(`${eventPrefix}-forge`, 'customer.subscription.created', {
      status: 'active',
    });

    await request(app.getHttpServer())
      .post('/api/v1/webhooks/stripe')
      .set('Content-Type', 'application/json')
      .send(payload)
      .expect(401);
    await postStripe(payload, 't=1,v1=forgee').expect(401);

    const count = await prisma.subscriptionEvent.count({
      where: { externalEventId: `${eventPrefix}-forge` },
    });
    expect(count).toBe(0);
  });

  it('active le premium via un webhook Stripe signé, REJOUÉ sans double traitement', async () => {
    const periodEnd = Math.floor(Date.now() / 1_000) + 30 * 24 * 3_600;
    const payload = stripeEvent(`${eventPrefix}-1`, 'customer.subscription.created', {
      status: 'active',
      current_period_end: periodEnd,
    });

    expect(data<{ received: boolean }>((await postStripe(payload).expect(200)).body)).toEqual({
      received: true,
    });
    const replay = data<{ received: boolean; duplicate?: boolean }>(
      (await postStripe(payload).expect(200)).body,
    );
    expect(replay.duplicate).toBe(true);

    const events = await prisma.subscriptionEvent.count({
      where: { externalEventId: `${eventPrefix}-1` },
    });
    expect(events).toBe(1);

    const me = data<SubscriptionMe>(
      (await authed(accessToken).get('/api/v1/subscriptions/me').expect(200)).body,
    );
    expect(me.isPremium).toBe(true);
    expect(me.subscription?.status).toBe('ACTIVE');

    // L'accès premium du catalogue s'ouvre immédiatement.
    await authed(accessToken).get(`/api/v1/exercises/${premiumExerciseSlug}`).expect(200);
  });

  it('l’expiration dégrade proprement : droits révoqués, catalogue refermé', async () => {
    const payload = stripeEvent(`${eventPrefix}-2`, 'customer.subscription.updated', {
      status: 'canceled',
      current_period_end: Math.floor(Date.now() / 1_000) - 3_600, // période finie
    });
    await postStripe(payload).expect(200);

    const me = data<SubscriptionMe>(
      (await authed(accessToken).get('/api/v1/subscriptions/me').expect(200)).body,
    );
    expect(me.isPremium).toBe(false);
    expect(me.subscription?.status).toBe('CANCELED');

    await authed(accessToken).get(`/api/v1/exercises/${premiumExerciseSlug}`).expect(403);
  });

  it('un produit inconnu est journalisé en erreur, sans casser l’accusé de réception', async () => {
    const payload = stripeEvent(`${eventPrefix}-3`, 'customer.subscription.created', {
      status: 'active',
      items: { data: [{ price: { id: 'price_inconnu' } }] },
    });
    await postStripe(payload).expect(200);

    const event = await prisma.subscriptionEvent.findFirstOrThrow({
      where: { externalEventId: `${eventPrefix}-3` },
    });
    expect(event.processedAt).toBeNull();
    expect(event.processingError).toContain('price_inconnu');
  });

  it('RevenueCat : Bearer requis, achat puis expiration projetés', async () => {
    const purchase = JSON.stringify({
      event: {
        id: `${eventPrefix}-rc-1`,
        type: 'INITIAL_PURCHASE',
        app_user_id: rcUserId,
        product_id: 'carlys_premium_monthly',
        original_transaction_id: `rc_e2e_${rcUserId}`,
        expiration_at_ms: Date.now() + 30 * 24 * 3_600_000,
      },
    });

    await request(app.getHttpServer())
      .post('/api/v1/webhooks/revenuecat')
      .set('Content-Type', 'application/json')
      .set('Authorization', 'Bearer mauvais-secret-0123456789')
      .send(purchase)
      .expect(401);

    await request(app.getHttpServer())
      .post('/api/v1/webhooks/revenuecat')
      .set('Content-Type', 'application/json')
      .set('Authorization', `Bearer ${REVENUECAT_SECRET}`)
      .send(purchase)
      .expect(200);

    let me = data<SubscriptionMe>(
      (await authed(rcAccessToken).get('/api/v1/subscriptions/me').expect(200)).body,
    );
    expect(me.isPremium).toBe(true);
    expect(me.subscription?.provider).toBe('REVENUECAT');

    const expiration = JSON.stringify({
      event: {
        id: `${eventPrefix}-rc-2`,
        type: 'EXPIRATION',
        app_user_id: rcUserId,
        product_id: 'carlys_premium_monthly',
        original_transaction_id: `rc_e2e_${rcUserId}`,
        expiration_at_ms: Date.now() - 3_600_000,
      },
    });
    await request(app.getHttpServer())
      .post('/api/v1/webhooks/revenuecat')
      .set('Content-Type', 'application/json')
      .set('Authorization', `Bearer ${REVENUECAT_SECRET}`)
      .send(expiration)
      .expect(200);

    me = data<SubscriptionMe>(
      (await authed(rcAccessToken).get('/api/v1/subscriptions/me').expect(200)).body,
    );
    expect(me.isPremium).toBe(false);
    expect(me.subscription?.status).toBe('EXPIRED');
  });

  it('le catalogue annonce l’achat dès que clé et prix sont configurés côté serveur', async () => {
    const offers = data<SubscriptionOffersResponse>(
      (await authed(accessToken).get('/api/v1/subscriptions/offers').expect(200)).body,
    );
    expect(offers.checkoutAvailable).toBe(true);
    expect(offers.offers.map((offer) => offer.id)).toContain(MONTHLY_OFFER_ID);
  });

  it('checkout : offre inconnue ou corps invalide refusés, aucune session ouverte', async () => {
    const before = checkoutCalls.length;
    await authed(accessToken)
      .post('/api/v1/subscriptions/checkout')
      .send({ id: randomUUID(), offerId: 'offre-fantome' })
      .expect(400);
    await authed(accessToken)
      .post('/api/v1/subscriptions/checkout')
      .send({ offerId: MONTHLY_OFFER_ID })
      .expect(400);
    await authed(accessToken)
      .post('/api/v1/subscriptions/checkout')
      .send({ id: 'pas-un-uuid', offerId: MONTHLY_OFFER_ID })
      .expect(400);
    await request(app.getHttpServer())
      .post('/api/v1/subscriptions/checkout')
      .send({ id: randomUUID(), offerId: MONTHLY_OFFER_ID })
      .expect(401);
    expect(checkoutCalls).toHaveLength(before);
  });

  it('checkout : une session s’ouvre pour l’offre mensuelle, sans accorder le moindre droit', async () => {
    const deviceId = randomUUID();
    const session = data<CheckoutSession>(
      (
        await authed(accessToken)
          .post('/api/v1/subscriptions/checkout')
          .send({ id: deviceId, offerId: MONTHLY_OFFER_ID })
          .expect(201)
      ).body,
    );
    expect(session).toEqual({
      url: `https://checkout.stripe.test/${deviceId}`,
      provider: 'STRIPE',
    });
    // Le serveur a bien demandé la session au fournisseur, avec le prix de
    // l'offre et l'identifiant de l'appareil comme clé d'idempotence.
    expect(checkoutCalls.at(-1)).toMatchObject({
      userId,
      priceId: 'price_carlys_premium_monthly',
      idempotencyKey: deviceId,
    });

    // Rien n'a changé côté droits : seul le webhook signé accorde Premium.
    const me = data<SubscriptionMe>(
      (await authed(accessToken).get('/api/v1/subscriptions/me').expect(200)).body,
    );
    expect(me.isPremium).toBe(false);
  });
});
