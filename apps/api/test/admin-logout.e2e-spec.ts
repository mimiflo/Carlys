process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import { type AdminLoginChallenge, type ApiSuccessEnvelope } from '@carlys/api-contracts';
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
import { bootstrapAdmin } from '../src/cli/admin-bootstrap';
import { totpCode } from '../src/modules/admin/application/totp';
import { PasswordService } from '../src/modules/auth/application/password.service';
import { adminSession, issueTestTotp } from './support/admin-session';

const ADMIN_PASSWORD = 'MotDePasseAdmin42!';
const NEW_PASSWORD = 'NouveauMotDePasse42!';

/**
 * Révocation des sessions du back-office : le jeton d'administration vit
 * douze heures, et sans révocation il survivait à la déconnexion comme à la
 * réinitialisation du mot de passe. Chaque jeton porte l'époque de session
 * du compte (`ep`) ; la déconnexion, `--reset-password` et `--reset-2fa`
 * l'incrémentent, et l'ancien jeton reçoit 401.
 *
 * Une adresse par scénario : `adminSession` ne tient que deux connexions par
 * adresse (anti-rejeu des codes). Budget de connexions : 6 sur 10 / 60 s.
 */
describe('Déconnexion et révocation des sessions du back-office (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  const emails = {
    logout: `e2e-logout-${randomUUID()}@carlys.test`,
    password: `e2e-logout-mdp-${randomUUID()}@carlys.test`,
    totp: `e2e-logout-2fa-${randomUUID()}@carlys.test`,
    challenge: `e2e-logout-defi-${randomUUID()}@carlys.test`,
  };
  const server = () => request(app.getHttpServer());
  const me = (token: string) =>
    server().get('/api/v1/admin/auth/me').set('Authorization', `Bearer ${token}`);
  const logout = (token: string) =>
    server().post('/api/v1/admin/auth/logout').set('Authorization', `Bearer ${token}`);
  const session = async (email: string, password = ADMIN_PASSWORD) =>
    (await adminSession(server, email, password)).accessToken;
  const resetPassword = (email: string) =>
    bootstrapAdmin(
      {
        email,
        role: 'superadmin',
        displayName: '',
        resetPassword: true,
        roleExplicite: false,
        resetTotp: false,
      },
      NEW_PASSWORD,
      prisma,
      app.get(PasswordService),
    );

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
    const passwordHash = await argon2.hash(ADMIN_PASSWORD, { type: argon2.argon2id });
    await prisma.adminUser.createMany({
      data: Object.values(emails).map((email) => ({
        email,
        displayName: 'Admin déconnexion',
        passwordHash,
      })),
    });
  });

  afterAll(async () => {
    await prisma.adminUser.deleteMany({ where: { email: { in: Object.values(emails) } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('déconnexion : 204, puis l’ancien jeton reçoit 401 partout, déconnexion comprise', async () => {
    const token = await session(emails.logout);
    await me(token).expect(200);

    await logout(token).expect(204);

    await me(token).expect(401);
    await logout(token).expect(401);
  });

  it('déconnexion sans jeton, ou avec un jeton illisible : 401', async () => {
    await server().post('/api/v1/admin/auth/logout').expect(401);
    await logout('pas-un-jeton').expect(401);
  });

  it('--reset-password : l’ancien jeton reçoit 401, le nouveau mot de passe rouvre', async () => {
    const token = await session(emails.password);
    await me(token).expect(200);

    await resetPassword(emails.password);

    await me(token).expect(401);
    await me(await session(emails.password, NEW_PASSWORD)).expect(200);
  });

  it('--reset-2fa : l’ancien jeton reçoit 401', async () => {
    const token = await session(emails.totp);
    await me(token).expect(200);

    await issueTestTotp(emails.totp);

    await me(token).expect(401);
  });

  it('un défi obtenu AVANT --reset-password n’ouvre plus de session', async () => {
    const secret = await issueTestTotp(emails.challenge);
    const { challengeToken } = (
      (
        await server()
          .post('/api/v1/admin/auth/login')
          .send({ email: emails.challenge, password: ADMIN_PASSWORD })
          .expect(200)
      ).body as ApiSuccessEnvelope<AdminLoginChallenge>
    ).data;

    await resetPassword(emails.challenge);

    await server()
      .post('/api/v1/admin/auth/totp')
      .send({ challengeToken, code: totpCode(secret, Math.floor(Date.now() / 1000)) })
      .expect(401);
  });
});
