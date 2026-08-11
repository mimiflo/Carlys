process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import { type ApiSuccessEnvelope, type AuthResult } from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';

/**
 * Notifications push : enregistrement idempotent des jetons d'appareil,
 * réaffectation quand l'appareil change de compte, oubli limité à ses
 * propres jetons. L'ENVOI, lui, est désactivé sans compte de service —
 * exactement la situation de la CI.
 */
describe('Notifications (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let tokenA: string;
  let tokenB: string;
  let userIdA: string;
  let userIdB: string;

  const emailA = `e2e-notifications-a-${randomUUID()}@carlys.test`;
  const emailB = `e2e-notifications-b-${randomUUID()}@carlys.test`;
  const deviceToken = `jeton-e2e-${randomUUID()}`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const authed = (token: string) => ({
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) =>
      request(app.getHttpServer()).delete(url).set('Authorization', `Bearer ${token}`),
  });

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const register = async (email: string, displayName: string): Promise<AuthResult> => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ email, password: 'MotDePasseSolide42', displayName })
        .expect(201);
      return data<AuthResult>(response.body);
    };

    const a = await register(emailA, 'Alice');
    const b = await register(emailB, 'Boris');
    tokenA = a.tokens.accessToken;
    tokenB = b.tokens.accessToken;
    userIdA = a.user.id;
    userIdB = b.user.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: [emailA, emailB] } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('refuse les requêtes sans authentification', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/notifications/device-tokens')
      .send({ token: deviceToken, platform: 'ANDROID' })
      .expect(401);
  });

  it('enregistre le jeton — et le rejeu est sans effet (idempotent)', async () => {
    await authed(tokenA)
      .post('/api/v1/notifications/device-tokens')
      .send({ token: deviceToken, platform: 'ANDROID' })
      .expect(204);
    await authed(tokenA)
      .post('/api/v1/notifications/device-tokens')
      .send({ token: deviceToken, platform: 'ANDROID' })
      .expect(204);

    const rows = await prisma.deviceToken.findMany({ where: { token: deviceToken } });
    expect(rows).toHaveLength(1);
    expect(rows[0]?.userId).toBe(userIdA);
  });

  it('rejette une plateforme inconnue', async () => {
    await authed(tokenA)
      .post('/api/v1/notifications/device-tokens')
      .send({ token: deviceToken, platform: 'WINDOWS_PHONE' })
      .expect(400);
  });

  it('changer de compte sur le même appareil RÉAFFECTE le jeton', async () => {
    await authed(tokenB)
      .post('/api/v1/notifications/device-tokens')
      .send({ token: deviceToken, platform: 'ANDROID' })
      .expect(204);

    const rows = await prisma.deviceToken.findMany({ where: { token: deviceToken } });
    expect(rows).toHaveLength(1);
    expect(rows[0]?.userId).toBe(userIdB);
  });

  it('on ne peut pas faire oublier le jeton d’un AUTRE compte', async () => {
    // Le jeton appartient à Boris : la demande d'Alice aboutit (idempotence,
    // pas d'énumération) mais ne retire rien.
    await authed(tokenA)
      .delete('/api/v1/notifications/device-tokens')
      .send({ token: deviceToken })
      .expect(204);
    expect(await prisma.deviceToken.count({ where: { token: deviceToken } })).toBe(1);
  });

  it('la déconnexion fait oublier le jeton — et le rejeu reste silencieux', async () => {
    await authed(tokenB)
      .delete('/api/v1/notifications/device-tokens')
      .send({ token: deviceToken })
      .expect(204);
    await authed(tokenB)
      .delete('/api/v1/notifications/device-tokens')
      .send({ token: deviceToken })
      .expect(204);
    expect(await prisma.deviceToken.count({ where: { token: deviceToken } })).toBe(0);
  });

  it('sans compte de service Firebase, une action sociale N’ÉCHOUE pas', async () => {
    // Boris enregistre un jeton puis Alice lui envoie une demande d'ami :
    // l'envoi push est désactivé (pas de FIREBASE_SERVICE_ACCOUNT_JSON en
    // test) et la demande aboutit quand même — la notification est un
    // à-côté, jamais une condition.
    await authed(tokenB)
      .post('/api/v1/notifications/device-tokens')
      .send({ token: deviceToken, platform: 'ANDROID' })
      .expect(204);
    await authed(tokenA).post('/api/v1/community/requests').send({ email: emailB }).expect(202);
  });
});
