process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type AdminLoginResult,
  type ApiSuccessEnvelope,
  type AuthResult,
  type EntitlementsResponse,
  type ManagedEntitlement,
  type ManagedUserDetail,
  PREMIUM_ENTITLEMENT_KEYS,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PaymentProvider, PrismaClient, SubscriptionStatus } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { AuditService } from '../src/modules/audit/audit.service';
import { EntitlementsService } from '../src/modules/subscriptions/application/entitlements.service';
import { SubscriptionsRepository } from '../src/modules/subscriptions/infrastructure/subscriptions.repository';
import { createAdminAccount } from './support/admin-fixture';

const ADMIN_PASSWORD = 'MotDePasseAdmin42!';

/**
 * Premium de la fiche d'administration : l'ORIGINE de chaque droit est
 * visible, et une décision manuelle se lève (« rendre la main à
 * l'abonnement ») au lieu de couper pour toujours un accès payé.
 */
describe('Administration — origine des droits et retour à l’abonnement (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let adminToken: string;
  let supportToken: string;
  const suffix = randomUUID();
  const adminEmail = `e2e-adm-droits-${suffix}@carlys.test`;
  const supportEmail = `e2e-adm-droits-support-${suffix}@carlys.test`;
  const payingEmail = `e2e-adm-droits-payant-${suffix}@carlys.test`;
  const freeEmail = `e2e-adm-droits-gratuit-${suffix}@carlys.test`;
  let payingId: string;
  let payingToken: string;
  let freeId: string;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const as = (token: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${token}`),
    put: (url: string) => server().put(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${token}`),
  });
  const premiumOf = (detail: ManagedUserDetail): ManagedEntitlement => {
    const entitlement = detail.entitlements.find((row) => row.key === 'premium_exercises');
    if (entitlement === undefined) {
      throw new Error('premium_exercises absent de la fiche');
    }
    return entitlement;
  };
  const login = async (email: string): Promise<string> =>
    data<AdminLoginResult>(
      (
        await server()
          .post('/api/v1/admin/auth/login')
          .send({ email, password: ADMIN_PASSWORD })
          .expect(200)
      ).body,
    ).accessToken;

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    await createAdminAccount(prisma, {
      email: adminEmail,
      password: ADMIN_PASSWORD,
      roleSlug: 'e2e-droits-super',
      permissions: ['user:read', 'entitlement:grant'],
    });
    await createAdminAccount(prisma, {
      email: supportEmail,
      password: ADMIN_PASSWORD,
      roleSlug: 'e2e-droits-support',
      permissions: ['user:read'],
    });
    adminToken = await login(adminEmail);
    supportToken = await login(supportEmail);

    const register = async (email: string) =>
      data<AuthResult>(
        (
          await server()
            .post('/api/v1/auth/register')
            .send({ email, password: 'MotDePasseSolide42', displayName: 'Membre' })
            .expect(201)
        ).body,
      );
    const paying = await register(payingEmail);
    payingId = paying.user.id;
    payingToken = paying.tokens.accessToken;
    freeId = (await register(freeEmail)).user.id;

    // Un abonnement Stripe ACTIF, projeté comme le ferait le webhook.
    const plan = await prisma.subscriptionPlan.upsert({
      where: { slug: 'premium' },
      update: {},
      create: { slug: 'premium', name: 'Premium' },
    });
    for (const entitlementKey of PREMIUM_ENTITLEMENT_KEYS) {
      await prisma.subscriptionPlanEntitlement.upsert({
        where: { planId_entitlementKey: { planId: plan.id, entitlementKey } },
        update: {},
        create: { planId: plan.id, entitlementKey },
      });
    }
    await prisma.subscription.create({
      data: {
        userId: payingId,
        planId: plan.id,
        provider: PaymentProvider.STRIPE,
        externalSubscriptionId: `sub_e2e_${suffix}`,
        status: SubscriptionStatus.ACTIVE,
        currentPeriodEnd: new Date(Date.now() + 20 * 86_400_000),
      },
    });
    await renouveler();
  });

  /** Ce que fait un webhook de renouvellement : recalculer depuis l'abonnement. */
  const renouveler = async (): Promise<void> => {
    const [subscription] = await app.get(SubscriptionsRepository).listSubscriptions(payingId);
    if (subscription === undefined) {
      throw new Error('abonnement de test absent');
    }
    await app.get(EntitlementsService).syncFromSubscription(subscription);
  };

  afterAll(async () => {
    await app.close();
    await prisma.auditLog.deleteMany({
      where: { adminUser: { email: { in: [adminEmail, supportEmail] } } },
    });
    await prisma.adminUser.deleteMany({ where: { email: { in: [adminEmail, supportEmail] } } });
    await prisma.adminRole.deleteMany({
      where: { slug: { in: ['e2e-droits-super', 'e2e-droits-support'] } },
    });
    await prisma.user.deleteMany({ where: { email: { in: [payingEmail, freeEmail] } } });
    await prisma.$disconnect();
  });

  it('un accès payé se lit comme tel : source SUBSCRIPTION, fournisseur, abonnement en cours', async () => {
    const detail = data<ManagedUserDetail>(
      (await as(adminToken).get(`/api/v1/admin/users/${payingId}`).expect(200)).body,
    );
    expect(premiumOf(detail)).toMatchObject({
      isActive: true,
      source: 'SUBSCRIPTION',
      provider: 'STRIPE',
    });
    expect(detail.paidSubscription).toMatchObject({ provider: 'STRIPE', status: 'ACTIVE' });
  });

  it('couper puis rendre la main : l’accès payé revient, le renouvellement ne le recoupe plus', async () => {
    const coupe = data<ManagedUserDetail>(
      (
        await as(adminToken)
          .put(`/api/v1/admin/users/${payingId}/entitlements`)
          .send({ key: 'premium_exercises', isActive: false, reason: 'Contrôle de fraude' })
          .expect(200)
      ).body,
    );
    expect(premiumOf(coupe)).toMatchObject({ isActive: false, source: 'MANUAL_REVOCATION' });
    // La coupure n'arrête pas la facturation : la fiche le dit encore.
    expect(coupe.paidSubscription).toMatchObject({ provider: 'STRIPE' });

    // Un renouvellement respecte la décision manuelle (règle voulue).
    await renouveler();
    const toujoursCoupe = data<ManagedUserDetail>(
      (await as(adminToken).get(`/api/v1/admin/users/${payingId}`).expect(200)).body,
    );
    expect(premiumOf(toujoursCoupe).source).toBe('MANUAL_REVOCATION');

    const rendu = data<ManagedUserDetail>(
      (
        await as(adminToken)
          .delete(`/api/v1/admin/users/${payingId}/entitlements/premium_exercises`)
          .expect(200)
      ).body,
    );
    expect(premiumOf(rendu)).toMatchObject({
      isActive: true,
      source: 'SUBSCRIPTION',
      provider: 'STRIPE',
    });

    const cote = data<EntitlementsResponse>(
      (
        await server()
          .get('/api/v1/entitlements')
          .set('Authorization', `Bearer ${payingToken}`)
          .expect(200)
      ).body,
    );
    expect(cote.isPremium).toBe(true);

    // L'audit s'écrit en tâche de fond : on attend ce qui est en vol.
    await app.get(AuditService).flush();
    const audit = await prisma.auditLog.findMany({
      where: { userId: payingId, resourceType: 'entitlement' },
      orderBy: { createdAt: 'asc' },
      select: { action: true, metadata: true },
    });
    expect(audit.map((row) => row.action)).toEqual([
      'admin.entitlement_revoked',
      'admin.entitlement_released',
    ]);
    expect(audit[0]?.metadata).toMatchObject({ reason: 'Contrôle de fraude' });
    expect(audit[1]?.metadata).toMatchObject({
      previousSource: 'MANUAL_REVOCATION',
      removed: true,
    });
  });

  it('un octroi de courtoisie se retire vraiment : retour à NONE, plus aucune ligne manuelle', async () => {
    const offert = data<ManagedUserDetail>(
      (
        await as(adminToken)
          .put(`/api/v1/admin/users/${freeId}/entitlements`)
          .send({ key: 'premium_exercises', isActive: true })
          .expect(200)
      ).body,
    );
    expect(premiumOf(offert)).toMatchObject({ isActive: true, source: 'MANUAL_GRANT' });
    expect(offert.paidSubscription).toBeNull();

    const rendu = data<ManagedUserDetail>(
      (
        await as(adminToken)
          .delete(`/api/v1/admin/users/${freeId}/entitlements/premium_exercises`)
          .expect(200)
      ).body,
    );
    expect(premiumOf(rendu)).toMatchObject({ isActive: false, source: 'NONE' });
    expect(rendu.isPremium).toBe(false);
    expect(
      await prisma.userEntitlement.count({
        where: { userId: freeId, entitlementKey: 'premium_exercises' },
      }),
    ).toBe(0);
  });

  it('couper exige une raison : absente, vide ou trop longue, rien n’est coupé', async () => {
    // Le back-office l'exigeait déjà dans son formulaire ; un appel direct à
    // l'API coupait pourtant l'accès d'un membre sans rien dire à l'audit.
    const couper = (extra: Record<string, unknown>) =>
      as(adminToken)
        .put(`/api/v1/admin/users/${freeId}/entitlements`)
        .send({ key: 'premium_exercises', isActive: false, ...extra });
    const raison400 = async (extra: Record<string, unknown>) => {
      const refus = await couper(extra).expect(400);
      expect(JSON.stringify(refus.body)).toContain('reason');
    };

    await raison400({});
    await raison400({ reason: null });
    await raison400({ reason: '   ' });
    await raison400({ reason: 'x'.repeat(501) });
    expect(
      await prisma.userEntitlement.count({
        where: { userId: freeId, entitlementKey: 'premium_exercises' },
      }),
    ).toBe(0);

    // La borne est inclusive, et elle se mesure APRÈS élagage des espaces.
    await couper({ reason: ` ${'x'.repeat(500)} ` }).expect(200);
    // Offrir reste possible sans raison : seule la coupure prive un membre.
    await as(adminToken)
      .put(`/api/v1/admin/users/${freeId}/entitlements`)
      .send({ key: 'premium_exercises', isActive: true })
      .expect(200);
    await as(adminToken)
      .delete(`/api/v1/admin/users/${freeId}/entitlements/premium_exercises`)
      .expect(200);
  });

  it('garde : permission entitlement:grant exigée, clé et identifiant validés', async () => {
    await as(supportToken)
      .delete(`/api/v1/admin/users/${freeId}/entitlements/premium_exercises`)
      .expect(403);
    await as(adminToken)
      .delete(`/api/v1/admin/users/${freeId}/entitlements/cle_inconnue`)
      .expect(400);
    await as(adminToken)
      .delete('/api/v1/admin/users/pas-un-uuid/entitlements/premium_exercises')
      .expect(400);
    await as(adminToken)
      .delete(`/api/v1/admin/users/${randomUUID()}/entitlements/premium_exercises`)
      .expect(404);
  });
});
