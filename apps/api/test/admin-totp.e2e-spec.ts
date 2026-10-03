process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type AdminLoginChallenge,
  type AdminLoginResult,
  type ApiSuccessEnvelope,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { totpCode } from '../src/modules/admin/application/totp';
import { issueTestTotp } from './support/admin-session';

const ADMIN_PASSWORD = 'MotDePasseAdmin42!';

/**
 * Double authentification du back-office, de bout en bout : le mot de passe
 * juste n'ouvre PAS la session, seul un code juste et inutilisé le fait ; et
 * le secret ne s'émet qu'à la commande de l'opérateur, jamais à la page.
 * Budget de la route de connexion (10 / 60 s) : 5 connexions ici.
 */
describe('Double authentification du back-office (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  const email = `e2e-totp-${randomUUID()}@carlys.test`;
  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const now = () => Math.floor(Date.now() / 1000);
  const login = async () =>
    data<AdminLoginChallenge>(
      (
        await server()
          .post('/api/v1/admin/auth/login')
          .send({ email, password: ADMIN_PASSWORD })
          .expect(200)
      ).body,
    );
  const totp = (challengeToken: string, code: string) =>
    server().post('/api/v1/admin/auth/totp').send({ challengeToken, code });

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
    await prisma.adminUser.create({
      data: {
        email,
        displayName: 'Admin 2FA',
        passwordHash: await argon2.hash(ADMIN_PASSWORD, { type: argon2.argon2id }),
      },
    });
  });

  afterAll(async () => {
    await prisma.adminUser.deleteMany({ where: { email } });
    await prisma.$disconnect();
    await app.close();
  });

  it('sans secret émis par l’opérateur : 403, rien à scanner', async () => {
    const res = await server()
      .post('/api/v1/admin/auth/login')
      .send({ email, password: ADMIN_PASSWORD })
      .expect(403);
    expect(JSON.stringify(res.body)).not.toContain('otpauth');
  });

  it('enrôlement, code faux, code juste, rejeu, jeton d’étape refusé comme session', async () => {
    const secret = await issueTestTotp(email);
    // Le secret est chiffré en base, jamais en clair.
    const stored = await prisma.adminUser.findUniqueOrThrow({ where: { email } });
    expect(stored.totpSecret).not.toContain(secret.toString('base64url'));
    expect(stored.totpEnabledAt).toBeNull();

    const first = await login();
    expect(Object.keys(first)).toEqual(['challengeToken']);

    // Le jeton d'étape n'ouvre RIEN au back-office.
    await server()
      .get('/api/v1/admin/auth/me')
      .set('Authorization', `Bearer ${first.challengeToken}`)
      .expect(401);

    await totp(first.challengeToken, '000000').expect(401);

    const code = totpCode(secret, now());
    const session = data<AdminLoginResult>(
      (await totp(first.challengeToken, code).expect(200)).body,
    );
    await server()
      .get('/api/v1/admin/auth/me')
      .set('Authorization', `Bearer ${session.accessToken}`)
      .expect(200);
    const enrolled = await prisma.adminUser.findUniqueOrThrow({ where: { email } });
    expect(enrolled.totpEnabledAt).not.toBeNull();
    expect(enrolled.totpFailedAttempts).toBe(0);

    // Connexion suivante : un code déjà servi est refusé.
    const second = await login();
    await totp(second.challengeToken, code).expect(401);
    await totp(second.challengeToken, totpCode(secret, now() + 30)).expect(200);
  });

  it('20 codes faux d’affilée : gelée, même le bon code ; --reset-2fa la rouvre', async () => {
    const secret = await issueTestTotp(email);
    const { challengeToken } = await login();
    await prisma.adminUser.update({ where: { email }, data: { totpFailedAttempts: 20 } });
    await totp(challengeToken, totpCode(secret, now())).expect(403);

    // Le nouveau secret remplace l'ancien : l'ancien ne vaut plus rien.
    const fresh = await issueTestTotp(email);
    const again = await login();
    await totp(again.challengeToken, totpCode(secret, now())).expect(401);
    await totp(again.challengeToken, totpCode(fresh, now())).expect(200);
  });
});
