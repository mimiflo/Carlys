process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = process.env.CARLYS_E2E_LOG ?? 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';
process.env.STRIPE_SECRET_KEY ??= 'sk_test_e2e_0123456789abcdef';
process.env.STRIPE_WEBHOOK_SECRET ??= 'whsec_e2e_stripe_0123456789';

import {
  type AccountDeletionResult,
  type ApiErrorEnvelope,
  type ApiSuccessEnvelope,
  type AuthResult,
  type Encouragement,
  type FriendChallenge,
  type League,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PaymentProvider, PrismaClient, SubscriptionStatus } from '@prisma/client';
import { createHmac, randomInt, randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { periodKeyOf } from '../src/modules/community/domain/league-ladder';
import { type StripeSimule, simulerStripe } from './support/stripe-frontier';
import { reinitialiserDebit } from './support/throttle';

const PASSWORD = 'MotDePasseSolide42';

/**
 * SUPPRIMER SON COMPTE, vu de l'argent et des autres (décisions du
 * 27 septembre 2026) : l'abonnement Stripe est résilié AVANT la suppression,
 * qui est refusée si Stripe ne l'a pas fait ; un abonnement de magasin est
 * signalé ; et la personne sort tout de suite de la ligue, des défis entre
 * amis et du fil d'encouragements des autres.
 */
describe('Suppression de compte (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  const idsCrees: string[] = [];
  let stripe: StripeSimule;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const as = (token: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) => server().post(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${token}`),
  });

  const register = async (name: string): Promise<AuthResult & { email: string }> => {
    const email = `e2e-suppr-${name}-${randomUUID()}@carlys.test`;
    const result = data<AuthResult>(
      (
        await server()
          .post('/api/v1/auth/register')
          .send({ email, password: PASSWORD, displayName: name })
          .expect(201)
      ).body,
    );
    idsCrees.push(result.user.id);
    return { ...result, email };
  };

  const supprimer = (u: AuthResult) =>
    as(u.tokens.accessToken).delete('/api/v1/users/me').send({ password: PASSWORD });

  /** Un webhook Stripe signé ; `id` : l'identifiant de l'événement envoyé. */
  const webhookStripe = (type: string, objet: Record<string, unknown>) => {
    const id = `evt_suppr_${randomUUID()}`;
    const corps = JSON.stringify({
      id,
      type,
      created: Math.floor(Date.now() / 1_000),
      data: { object: { items: { data: [{ price: { id: 'price_quelconque' } }] }, ...objet } },
    });
    const t = Math.floor(Date.now() / 1_000);
    const v1 = createHmac('sha256', process.env.STRIPE_WEBHOOK_SECRET ?? '')
      .update(`${t}.${corps}`)
      .digest('hex');
    return Object.assign(
      server()
        .post('/api/v1/webhooks/stripe')
        .set('Content-Type', 'application/json')
        .set('Stripe-Signature', `t=${t},v1=${v1}`)
        .send(corps),
      { id },
    );
  };

  const abonner = async (
    userId: string,
    provider: PaymentProvider,
    status: SubscriptionStatus = SubscriptionStatus.ACTIVE,
  ) => {
    const plan = await prisma.subscriptionPlan.upsert({
      where: { slug: 'premium' },
      update: {},
      create: { slug: 'premium', name: 'Premium' },
    });
    return prisma.subscription.create({
      data: {
        userId,
        planId: plan.id,
        provider,
        externalSubscriptionId: `sub_suppr_${randomUUID()}`,
        status,
      },
    });
  };

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
    stripe = simulerStripe();
  });

  beforeEach(async () => {
    stripe.reinitialiser();
    await reinitialiserDebit();
  });

  afterAll(async () => {
    jest.restoreAllMocks();
    await app.close();
    await prisma.user.deleteMany({ where: { id: { in: idsCrees } } });
    await prisma.$disconnect();
  });

  describe('D1 — l’abonnement', () => {
    it('Stripe résilié AVANT la suppression ; le webhook qui suit est acquitté sans erreur', async () => {
      const u = await register('stripe');
      const abonnement = await abonner(u.user.id, PaymentProvider.STRIPE);

      const reponse = await supprimer(u).expect(200);

      expect(data<AccountDeletionResult>(reponse.body)).toEqual({
        storeSubscriptionStillActive: false,
      });
      expect(stripe.appels).toEqual([
        `DELETE https://api.stripe.com/v1/subscriptions/${abonnement.externalSubscriptionId}`,
      ]);
      const apres = await prisma.subscription.findUniqueOrThrow({ where: { id: abonnement.id } });
      expect(apres.status).toBe(SubscriptionStatus.CANCELED);

      // La résiliation déclenche `customer.subscription.deleted`, pour un
      // compte désormais supprimé : 200, rien de gardé, rien de rouvert.
      const evenement = webhookStripe('customer.subscription.deleted', {
        id: abonnement.externalSubscriptionId,
        status: 'canceled',
        metadata: { userId: u.user.id },
      });
      await evenement.expect(200);
      expect(
        await prisma.subscriptionEvent.count({ where: { externalEventId: evenement.id } }),
      ).toBe(0);
      expect(stripe.appels).toHaveLength(1);

      // Un paiement conclu juste AVANT la suppression, dont le webhook arrive
      // juste APRÈS : la suppression n'en savait rien, il est résilié à
      // réception.
      const tardif = `sub_tardif_${randomUUID()}`;
      await webhookStripe('customer.subscription.created', {
        id: tardif,
        status: 'active',
        metadata: { userId: u.user.id },
      }).expect(200);
      expect(stripe.appels).toEqual([
        `DELETE https://api.stripe.com/v1/subscriptions/${abonnement.externalSubscriptionId}`,
        `DELETE https://api.stripe.com/v1/subscriptions/${tardif}`,
      ]);
    });

    it('Stripe en panne : 503 écrit pour la personne, et RIEN n’est supprimé', async () => {
      const u = await register('panne');
      const abonnement = await abonner(u.user.id, PaymentProvider.STRIPE);
      stripe.statut = 500;

      const reponse = await supprimer(u).expect(503);

      expect((reponse.body as ApiErrorEnvelope).error).toMatchObject({
        code: 'SERVICE_UNAVAILABLE',
        message:
          'On n’a pas pu arrêter ton abonnement, réessaie dans un instant ; ton compte n’est pas supprimé.',
      });
      // Le compte vit encore — sa session aussi — et l'abonnement est intact.
      await as(u.tokens.accessToken).get('/api/v1/users/me').expect(200);
      expect(
        (await prisma.subscription.findUniqueOrThrow({ where: { id: abonnement.id } })).status,
      ).toBe(SubscriptionStatus.ACTIVE);

      // Stripe revenu, la même demande aboutit.
      stripe.statut = 200;
      await supprimer(u).expect(200);
    });

    it('404 Stripe : déjà résilié, la suppression passe', async () => {
      const u = await register('deja');
      await abonner(u.user.id, PaymentProvider.STRIPE);
      stripe.statut = 404;

      await supprimer(u).expect(200);
      expect(
        (await prisma.user.findUniqueOrThrow({ where: { id: u.user.id } })).deletedAt,
      ).not.toBeNull();
    });

    it.each([SubscriptionStatus.TRIALING, SubscriptionStatus.PAST_DUE])(
      'abonnement Stripe %s : il peut encore prélever, il est résilié aussi',
      async (status) => {
        // En essai, Stripe prélève à la fin de l'essai ; en retard de
        // paiement, il retente. Supprimer son compte doit arrêter les deux.
        const u = await register(`statut-${status.toLowerCase()}`);
        const abonnement = await abonner(u.user.id, PaymentProvider.STRIPE, status);

        await supprimer(u).expect(200);

        expect(stripe.appels).toEqual([
          `DELETE https://api.stripe.com/v1/subscriptions/${abonnement.externalSubscriptionId}`,
        ]);
        expect(
          (await prisma.subscription.findUniqueOrThrow({ where: { id: abonnement.id } })).status,
        ).toBe(SubscriptionStatus.CANCELED);
      },
    );

    it.each([SubscriptionStatus.CANCELED, SubscriptionStatus.EXPIRED])(
      'abonnement Stripe %s : plus rien ne prélève, Stripe n’est pas appelé',
      async (status) => {
        const u = await register(`fini-${status.toLowerCase()}`);
        await abonner(u.user.id, PaymentProvider.STRIPE, status);

        await supprimer(u).expect(200);

        expect(stripe.appels).toEqual([]);
      },
    );

    it('webhook pour un compte que cette base n’a jamais connu : 200, et RIEN n’est résilié', async () => {
      // Base restaurée depuis une sauvegarde plus ancienne que l'abonné, ou
      // compte Stripe de test partagé avec un autre environnement : la
      // résiliation est irréversible, et cet abonnement n'est pas le nôtre.
      const evenement = webhookStripe('customer.subscription.updated', {
        id: `sub_inconnu_${randomUUID()}`,
        status: 'active',
        metadata: { userId: randomUUID() },
      });

      await evenement.expect(200);

      expect(stripe.appels).toEqual([]);
      expect(
        await prisma.subscriptionEvent.count({ where: { externalEventId: evenement.id } }),
      ).toBe(0);
    });

    it('abonnement de magasin : suppression permise, la réponse dit de le résilier soi-même', async () => {
      const u = await register('magasin');
      await abonner(u.user.id, PaymentProvider.REVENUECAT);

      const reponse = await supprimer(u).expect(200);

      expect(data<AccountDeletionResult>(reponse.body)).toEqual({
        storeSubscriptionStillActive: true,
      });
      expect(stripe.appels).toEqual([]);
    });
  });

  describe('D3 — ce que les autres voient', () => {
    const amis = async (x: AuthResult & { email: string }, y: AuthResult) => {
      await as(y.tokens.accessToken)
        .post('/api/v1/community/requests')
        .send({ email: x.email })
        .expect(202);
      const recues = data<Array<{ id: string; fromUserId?: string }>>(
        (await as(x.tokens.accessToken).get('/api/v1/community/requests').expect(200)).body,
      );
      for (const demande of recues) {
        await as(x.tokens.accessToken)
          .post(`/api/v1/community/requests/${demande.id}/accept`)
          .expect(204);
      }
    };
    const defier = async (createur: AuthResult, invites: string[]): Promise<string> => {
      const id = randomUUID();
      await as(createur.tokens.accessToken)
        .post('/api/v1/community/friend-challenges')
        .send({
          id,
          title: 'Qui court le plus',
          metric: 'WORKOUTS',
          durationDays: 7,
          invitedUserIds: invites,
        })
        .expect(201);
      return id;
    };
    const accepter = (u: AuthResult, id: string) =>
      as(u.tokens.accessToken).post(`/api/v1/community/friend-challenges/${id}/accept`).expect(201);

    it('sortie de la ligue, des défis entre amis et du fil des autres, tout de suite', async () => {
      const alice = await register('alice');
      const boris = await register('boris');
      const chloe = await register('chloe');
      await amis(alice, boris);
      await amis(alice, chloe);
      await amis(boris, chloe);

      // Ligue : Alice devant Boris, dans un groupe à part. Posée sur la
      // semaine d'aujourd'hui ET sur celle de dans dix minutes : si lundi
      // 00:00 UTC passe pendant le test, la lecture tombe quand même sur une
      // semaine préparée.
      const groupe = randomInt(10_000, 2_000_000_000);
      const semaines = [
        ...new Set([periodKeyOf(new Date()), periodKeyOf(new Date(Date.now() + 600_000))]),
      ];
      await prisma.communityPreference.createMany({
        data: [alice, boris].map((u) => ({ userId: u.user.id, joinsLeague: true })),
      });
      await prisma.leagueMembership.createMany({
        data: semaines.flatMap((periodKey) =>
          [
            { userId: alice.user.id, score: 300 },
            { userId: boris.user.id, score: 100 },
          ].map((ligne) => ({ ...ligne, periodKey, division: 'BRONZE' as const, cohort: groupe })),
        ),
      });

      // Défis : un lancé par Alice ; un de Boris contre Alice seule ; un de
      // Boris contre Alice ET Chloé.
      const deAlice = await defier(alice, [boris.user.id]);
      const seule = await defier(boris, [alice.user.id]);
      await accepter(alice, seule);
      const aTrois = await defier(boris, [alice.user.id, chloe.user.id]);
      await accepter(alice, aTrois);
      await accepter(chloe, aTrois);
      // Un défi de Boris qu'Alice a accepté et que Chloé a REFUSÉ : sans Alice,
      // plus personne en face, il sera annulé.
      const refuse = await defier(boris, [alice.user.id, chloe.user.id]);
      await accepter(alice, refuse);
      await as(chloe.tokens.accessToken)
        .delete(`/api/v1/community/friend-challenges/${refuse}/join`)
        .expect(204);
      // Un défi ÉCHU que personne n'a encore ouvert, donc pas encore réglé :
      // Alice y mène 5 à 1. Son résultat ne doit pas dépendre de la date de
      // la suppression.
      const echu = await defier(boris, [alice.user.id]);
      await accepter(alice, echu);
      for (const [u, contribution] of [
        [alice, 5],
        [boris, 1],
      ] as const) {
        await prisma.friendChallengeMember.update({
          where: { challengeId_userId: { challengeId: echu, userId: u.user.id } },
          data: { contribution },
        });
      }
      await prisma.friendChallenge.update({
        where: { id: echu },
        data: { endsAt: new Date(Date.now() - 86_400_000) },
      });

      await as(alice.tokens.accessToken)
        .post('/api/v1/community/encouragements')
        .send({ recipientUserId: boris.user.id, message: 'Bravo Boris !' })
        .expect(201);

      await supprimer(alice).expect(200);

      // Ligue : Alice n'est plus au classement de Boris, qui ne remonte pas
      // d'un cran — sa ligne reste pour le règlement de la semaine.
      const ligue = data<League>(
        (await as(boris.tokens.accessToken).get('/api/v1/community/league').expect(200)).body,
      );
      expect(ligue.standings.map((ligne) => [ligne.userId, ligne.rank])).toEqual([
        [boris.user.id, 2],
      ]);
      expect(
        await prisma.leagueMembership.count({
          where: { userId: alice.user.id, periodKey: ligue.periodKey },
        }),
      ).toBe(1);

      // Défis : celui d'Alice a disparu ; celui où elle était la seule
      // adversaire est annulé ; l'autre continue, sans elle.
      await as(boris.tokens.accessToken)
        .get(`/api/v1/community/friend-challenges/${deAlice}`)
        .expect(404);
      const annule = data<FriendChallenge>(
        (await as(boris.tokens.accessToken).get(`/api/v1/community/friend-challenges/${seule}`))
          .body,
      );
      expect(annule.status).toBe('CANCELLED');
      expect(annule.members.map((membre) => membre.userId)).toEqual([boris.user.id]);
      const continue_ = data<FriendChallenge>(
        (await as(chloe.tokens.accessToken).get(`/api/v1/community/friend-challenges/${aTrois}`))
          .body,
      );
      expect(continue_.status).toBe('OPEN');
      expect(continue_.members.map((membre) => membre.userId).sort()).toEqual(
        [boris.user.id, chloe.user.id].sort(),
      );

      // Un défi annulé est TERMINÉ : Chloé, qui l'avait refusé, ne peut plus
      // y entrer, et la liste de Boris le range après ceux en cours.
      await as(chloe.tokens.accessToken)
        .post(`/api/v1/community/friend-challenges/${refuse}/accept`)
        .expect(404);
      const liste = data<FriendChallenge[]>(
        (await as(boris.tokens.accessToken).get('/api/v1/community/friend-challenges').expect(200))
          .body,
      );
      const statuts = liste.map((defi) => defi.status);
      expect(statuts.filter((statut) => statut === 'OPEN')).toHaveLength(1);
      expect(statuts.lastIndexOf('OPEN')).toBeLessThan(statuts.indexOf('CANCELLED'));

      // Le défi échu est RÉGLÉ, pas annulé, et avec le score d'Alice : Boris
      // est deuxième. Sa ligne à elle part, comme d'un défi déjà clos.
      const regle = data<FriendChallenge>(
        (await as(boris.tokens.accessToken).get(`/api/v1/community/friend-challenges/${echu}`))
          .body,
      );
      expect(regle.status).toBe('CLOSED');
      expect(regle.members.map((membre) => [membre.userId, membre.rank])).toEqual([
        [boris.user.id, 2],
      ]);

      // Encouragements : plus rien d'Alice dans le fil de Boris.
      const fil = data<Encouragement[]>(
        (await as(boris.tokens.accessToken).get('/api/v1/community/feed').expect(200)).body,
      );
      expect(fil.filter((mot) => mot.fromUserId === alice.user.id)).toEqual([]);
    });
  });
});
