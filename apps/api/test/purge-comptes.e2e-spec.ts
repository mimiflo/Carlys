process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';
process.env.STRIPE_WEBHOOK_SECRET ??= 'whsec_e2e_stripe_0123456789';

import { type ApiSuccessEnvelope, type AuthResult } from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PaymentProvider, PrismaClient, SubscriptionStatus } from '@prisma/client';
import { createHmac, randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { AuditService } from '../src/modules/audit/audit.service';
import { purgeDeletedAccounts } from '../src/modules/users/application/deleted-accounts-purge';
import { PrismaDeletedAccountsLedger } from '../src/modules/users/infrastructure/deleted-accounts-ledger';
import { InMemoryObjectStore } from './support/in-memory-object-store';
import { reinitialiserDebit } from './support/throttle';

const PASSWORD = 'MotDePasseSolide42';

/**
 * La purge des comptes supprimés, contre une VRAIE base : un compte supprimé
 * depuis plus de 30 jours disparaît avec TOUT ce qui s'y rattache (les
 * cascades du schéma sont éprouvées pour de bon, pas supposées) ; un compte
 * supprimé hier, un compte actif et les données d'un ami restent.
 */
describe('Purge des comptes supprimés (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  const emails: string[] = [];
  const idsCrees: string[] = [];

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const as = (token: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) => server().post(url).set('Authorization', `Bearer ${token}`),
    put: (url: string) => server().put(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${token}`),
  });

  const register = async (name: string): Promise<AuthResult & { email: string }> => {
    const email = `e2e-purge-${name}-${randomUUID()}@carlys.test`;
    emails.push(email);
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

  /** Marque propre à CETTE exécution, posée dans la charge utile du webhook. */
  const marque = `personne-${randomUUID()}@exemple.test`;

  /** Un compte bien rempli : séance et séries, repas, modèle, programme, ligue, amitié… */
  const remplir = async (u: AuthResult, ami: AuthResult & { email: string }): Promise<void> => {
    const token = u.tokens.accessToken;
    const sessionId = randomUUID();
    await as(token)
      .post('/api/v1/workout-sessions')
      .send({ id: sessionId, startedAt: new Date(Date.now() - 3_600_000).toISOString() })
      .expect(201);
    await as(token)
      .post(`/api/v1/workout-sessions/${sessionId}/sets`)
      .send({
        id: randomUUID(),
        exerciseName: 'Squat',
        position: 0,
        reps: 5,
        weightKg: 100,
        completedAt: new Date().toISOString(),
      })
      .expect(201);
    await as(token).post(`/api/v1/workout-sessions/${sessionId}/complete`).send({}).expect(200);
    await as(token)
      .post('/api/v1/nutrition/meals')
      .send({ id: randomUUID(), name: 'Riz', kcal: 500, eatenAt: new Date().toISOString() })
      .expect(201);
    await as(token)
      .put(`/api/v1/programs/${randomUUID()}`)
      .send({
        name: 'Plan',
        weeksCount: 1,
        days: [{ id: randomUUID(), weekNumber: 1, dayOfWeek: 1 }],
      })
      .expect(201);
    await as(token).post('/api/v1/community/league/join').expect(201);
    await as(token).post('/api/v1/community/requests').send({ email: ami.email }).expect(202);
    const recues = data<Array<{ id: string }>>(
      (await as(ami.tokens.accessToken).get('/api/v1/community/requests').expect(200)).body,
    );
    await as(ami.tokens.accessToken)
      .post(`/api/v1/community/requests/${recues[0]?.id}/accept`)
      .expect(204);
    await as(token)
      .post('/api/v1/community/encouragements')
      .send({ recipientUserId: ami.user.id, message: 'Bravo !' })
      .expect(201);
    // Un abonnement et un événement de paiement : la charge utile brute du
    // webhook ne doit pas survivre au compte.
    const plan = await prisma.subscriptionPlan.upsert({
      where: { slug: 'premium' },
      update: {},
      create: { slug: 'premium', name: 'Premium' },
    });
    const abonnement = await prisma.subscription.create({
      data: {
        userId: u.user.id,
        planId: plan.id,
        provider: PaymentProvider.STRIPE,
        externalSubscriptionId: `sub_purge_${randomUUID()}`,
        status: SubscriptionStatus.CANCELED,
      },
    });
    await prisma.subscriptionEvent.create({
      data: {
        provider: PaymentProvider.STRIPE,
        externalEventId: `evt_purge_${randomUUID()}`,
        eventType: 'customer.subscription.deleted',
        payload: { email: marque },
        subscriptionId: abonnement.id,
      },
    });
  };

  const supprimer = async (u: AuthResult, joursDepuis: number): Promise<void> => {
    await as(u.tokens.accessToken)
      .delete('/api/v1/users/me')
      .send({ password: PASSWORD })
      .expect(204);
    await prisma.user.update({
      where: { id: u.user.id },
      data: { deletedAt: new Date(Date.now() - joursDepuis * 86_400_000) },
    });
  };

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
  });

  beforeEach(reinitialiserDebit);

  afterAll(async () => {
    await app.close();
    await prisma.user.deleteMany({ where: { id: { in: idsCrees } } });
    await prisma.$disconnect();
  });

  it('efface un compte supprimé depuis plus de 30 jours, et TOUT ce qui s’y rattache', async () => {
    const ancien = await register('ancien');
    const recent = await register('recent');
    const actif = await register('actif');
    await remplir(ancien, actif);
    await supprimer(ancien, 31);
    await supprimer(recent, 2);
    // Les lignes d'audit du compte, écrites en tâche de fond : drainées
    // AVANT d'être relevées, sinon la preuve de leur survie serait vide.
    await app.get(AuditService).flush();
    const audit = await prisma.auditLog.findMany({
      where: { userId: ancien.user.id },
      select: { id: true },
    });
    expect(audit.length).toBeGreaterThan(0);
    const store = new InMemoryObjectStore();
    await store.put(`meal-photos/${ancien.user.id}/orpheline.jpg`, Buffer.from('x'), 'image/jpeg');
    await store.put(`meal-photos/${recent.user.id}/gardee.jpg`, Buffer.from('x'), 'image/jpeg');
    const ledger = new PrismaDeletedAccountsLedger(prisma);

    // À blanc d'abord : rien ne bouge.
    const simulation = await purgeDeletedAccounts(ledger, store, {
      now: new Date(),
      delayDays: 30,
      dryRun: true,
    });
    expect(simulation.eligible).toBeGreaterThanOrEqual(1);
    expect(await prisma.user.count({ where: { id: ancien.user.id } })).toBe(1);

    const rapport = await purgeDeletedAccounts(ledger, store, {
      now: new Date(),
      delayDays: 30,
      dryRun: false,
    });
    expect(rapport.failures).toEqual([]);

    const userId = ancien.user.id;
    expect(await prisma.user.count({ where: { id: userId } })).toBe(0);
    const restes = {
      seances: await prisma.workoutSession.count({ where: { userId } }),
      repas: await prisma.mealEntry.count({ where: { userId } }),
      programmes: await prisma.program.count({ where: { userId } }),
      records: await prisma.personalRecord.count({ where: { userId } }),
      ligue: await prisma.leagueMembership.count({ where: { userId } }),
      amities: await prisma.friendship.count({
        where: { OR: [{ requesterId: userId }, { addresseeId: userId }] },
      }),
      encouragements: await prisma.encouragement.count({ where: { senderId: userId } }),
      abonnements: await prisma.subscription.count({ where: { userId } }),
      evenements: await prisma.subscriptionEvent.count({
        where: { payload: { path: ['email'], equals: marque } },
      }),
      profil: await prisma.userProfile.count({ where: { userId } }),
    };
    expect(restes).toEqual({
      seances: 0,
      repas: 0,
      programmes: 0,
      records: 0,
      ligue: 0,
      amities: 0,
      encouragements: 0,
      abonnements: 0,
      evenements: 0,
      profil: 0,
    });
    // Le journal d'audit reste — les MÊMES lignes —, sans le lien vers le compte.
    expect(
      await prisma.auditLog.findMany({
        where: { id: { in: audit.map((ligne) => ligne.id) } },
        select: { id: true, userId: true },
        orderBy: { id: 'asc' },
      }),
    ).toEqual(
      audit
        .map((ligne) => ({ id: ligne.id, userId: null }))
        .sort((a, b) => a.id.localeCompare(b.id)),
    );
    // Ses photos privées sont effacées ; celles d'un compte supprimé hier non.
    expect([...store.objects.keys()]).toEqual([`meal-photos/${recent.user.id}/gardee.jpg`]);

    // Le compte supprimé hier, le compte actif et l'ami restent.
    expect(await prisma.user.count({ where: { id: recent.user.id } })).toBe(1);
    expect(await prisma.user.count({ where: { id: actif.user.id } })).toBe(1);
  });

  it('--compte : l’effacement immédiat d’un compte supprimé hier ; un compte actif est refusé', async () => {
    const demande = await register('demande');
    const actif = await register('actif2');
    await supprimer(demande, 1);
    const ledger = new PrismaDeletedAccountsLedger(prisma);
    const store = new InMemoryObjectStore();

    const refus = await purgeDeletedAccounts(ledger, store, {
      now: new Date(),
      delayDays: 30,
      accountId: actif.user.id,
      dryRun: false,
    });
    expect(refus.refused).not.toBeNull();
    expect(await prisma.user.count({ where: { id: actif.user.id } })).toBe(1);

    const immediat = await purgeDeletedAccounts(ledger, store, {
      now: new Date(),
      delayDays: 30,
      accountId: demande.user.id,
      dryRun: false,
    });
    expect(immediat.erased).toBe(1);
    expect(await prisma.user.count({ where: { id: demande.user.id } })).toBe(0);
  });

  it('webhooks de paiement : rien ne survit à la purge, et un renouvellement ultérieur est acquitté sans être gardé', async () => {
    // Supprimer son compte ne résilie pas l'abonnement chez le fournisseur :
    // les événements continuent d'arriver, avant comme après la purge.
    const u = await register('paiement');
    const userId = u.user.id;
    const prix = `price_purge_${randomUUID()}`;
    const plan = await prisma.subscriptionPlan.upsert({
      where: { slug: 'premium' },
      update: {},
      create: { slug: 'premium', name: 'Premium' },
    });
    await prisma.subscriptionProduct.create({
      data: {
        planId: plan.id,
        provider: PaymentProvider.STRIPE,
        externalProductId: prix,
        billingPeriod: 'MONTHLY',
      },
    });
    const abonnementStripe = `sub_purge_${randomUUID()}`;
    const evenements: string[] = [];
    const webhook = (type: string, objet: Record<string, unknown>) => {
      const id = `evt_purge_${randomUUID()}`;
      evenements.push(id);
      const corps = JSON.stringify({
        id,
        type,
        created: Math.floor(Date.now() / 1_000),
        data: {
          object: {
            id: abonnementStripe,
            status: 'active',
            current_period_end: Math.floor(Date.now() / 1_000) + 30 * 86_400,
            metadata: { userId },
            items: { data: [{ price: { id: prix } }] },
            ...objet,
          },
        },
      });
      const t = Math.floor(Date.now() / 1_000);
      const v1 = createHmac('sha256', process.env.STRIPE_WEBHOOK_SECRET ?? '')
        .update(`${t}.${corps}`)
        .digest('hex');
      return server()
        .post('/api/v1/webhooks/stripe')
        .set('Content-Type', 'application/json')
        .set('Stripe-Signature', `t=${t},v1=${v1}`)
        .send(corps);
    };
    const gardes = () =>
      prisma.subscriptionEvent.findMany({ where: { externalEventId: { in: evenements } } });

    try {
      await webhook('customer.subscription.created', {}).expect(200);
      // Projection en échec (tarif pas encore chargé) : l'événement n'est
      // rattaché à AUCUN abonnement, et nomme pourtant le compte.
      await webhook('customer.subscription.updated', {
        items: { data: [{ price: { id: `price_inconnu_${randomUUID()}` } }] },
      }).expect(503);
      // Une facture porte l'adresse du client : rien à projeter, rien à garder.
      await webhook('invoice.paid', { customer_email: marque }).expect(200);
      expect(await gardes()).toHaveLength(2);
      expect((await gardes()).find((evenement) => evenement.subscriptionId === null)?.userId).toBe(
        userId,
      );

      await supprimer(u, 1);
      // Supprimé, pas encore effacé : aucun droit ne se rouvre, rien n'est gardé.
      await webhook('customer.subscription.updated', { status: 'active' }).expect(200);
      expect(await gardes()).toHaveLength(2);

      const purge = await purgeDeletedAccounts(
        new PrismaDeletedAccountsLedger(prisma),
        new InMemoryObjectStore(),
        { now: new Date(), delayDays: 30, accountId: userId, dryRun: false },
      );
      expect(purge.erased).toBe(1);
      expect(await gardes()).toEqual([]);

      // Le renouvellement du mois suivant, compte effacé : 200 et non 503 en
      // boucle, aucun abonnement recréé, aucune charge utile gardée.
      await webhook('customer.subscription.updated', { status: 'active' }).expect(200);
      expect(await gardes()).toEqual([]);
      expect(await prisma.subscription.count({ where: { userId } })).toBe(0);
    } finally {
      await prisma.subscriptionEvent.deleteMany({ where: { externalEventId: { in: evenements } } });
      await prisma.subscriptionProduct.deleteMany({ where: { externalProductId: prix } });
    }
  });
});
