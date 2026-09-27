process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type AdminLoginResult,
  type ApiSuccessEnvelope,
  type AuthResult,
  type AuthSession,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { createHash, randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { DeviceTokensRepository } from '../src/modules/notifications/infrastructure/device-tokens.repository';
import { createAdminAccount } from './support/admin-fixture';
import { reinitialiserDebit } from './support/throttle';

const PASSWORD = 'MotDePasseSolide42';
const ADMIN_PASSWORD = 'MotDePasseAdmin42!';

/**
 * Un jeton push appartient à la SESSION qui l'a enregistré : révoquer la
 * session le fait tomber. Sans ce lien, un téléphone perdu, déconnecté à
 * distance, affichait encore les notifications sur son écran verrouillé.
 */
describe('Jetons push rattachés à la session (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  const emails: string[] = [];
  const adminEmail = `e2e-push-admin-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

  const register = async (): Promise<AuthResult & { email: string }> => {
    const email = `e2e-push-${randomUUID()}@carlys.test`;
    emails.push(email);
    const res = await server()
      .post('/api/v1/auth/register')
      .send({ email, password: PASSWORD, displayName: 'Membre' })
      .expect(201);
    return { ...data<AuthResult>(res.body), email };
  };
  const login = async (email: string, password = PASSWORD): Promise<AuthResult> =>
    data<AuthResult>(
      (await server().post('/api/v1/auth/login').send({ email, password }).expect(200)).body,
    );
  const enregistrer = async (accessToken: string): Promise<string> => {
    const token = `jeton-${randomUUID()}`;
    await server()
      .post('/api/v1/notifications/device-tokens')
      .set(bearer(accessToken))
      .send({ token, platform: 'ANDROID' })
      .expect(204);
    return token;
  };
  const existe = async (token: string): Promise<boolean> =>
    (await prisma.deviceToken.count({ where: { token } })) === 1;

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
    await prisma.auditLog.deleteMany({ where: { adminUser: { email: adminEmail } } });
    await prisma.adminUser.deleteMany({ where: { email: adminEmail } });
    await prisma.adminRole.deleteMany({ where: { slug: 'e2e-push-suspension' } });
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
    await prisma.$disconnect();
  });

  it('le jeton porte la session qui l’a enregistré', async () => {
    const u = await register();
    const jeton = await enregistrer(u.tokens.accessToken);
    const ligne = await prisma.deviceToken.findUniqueOrThrow({ where: { token: jeton } });
    const sessions = await prisma.userSession.findMany({ where: { userId: u.user.id } });
    expect(sessions).toHaveLength(1);
    expect(ligne.sessionId).toBe(sessions[0]?.id);
  });

  it('déconnecter un appareil à distance supprime SES jetons, pas ceux de l’appareil courant', async () => {
    const u = await register();
    const telephonePerdu = await enregistrer(u.tokens.accessToken);
    const autre = await login(u.email);
    const telephoneCourant = await enregistrer(autre.tokens.accessToken);

    const sessions = data<AuthSession[]>(
      (await server().get('/api/v1/auth/sessions').set(bearer(autre.tokens.accessToken))).body,
    );
    const perdue = sessions.find((session) => !session.current);
    expect(perdue).toBeDefined();
    await server()
      .delete(`/api/v1/auth/sessions/${perdue?.id}`)
      .set(bearer(autre.tokens.accessToken))
      .expect(204);

    expect(await existe(telephonePerdu)).toBe(false);
    expect(await existe(telephoneCourant)).toBe(true);
  });

  it('changer de mot de passe fait tomber les jetons des AUTRES sessions', async () => {
    const u = await register();
    const ancien = await enregistrer(u.tokens.accessToken);
    const courant = await login(u.email);
    const jetonCourant = await enregistrer(courant.tokens.accessToken);

    await server()
      .post('/api/v1/auth/change-password')
      .set(bearer(courant.tokens.accessToken))
      .send({ currentPassword: PASSWORD, newPassword: 'NouveauMotDePasse42' })
      .expect(204);

    expect(await existe(ancien)).toBe(false);
    expect(await existe(jetonCourant)).toBe(true);
  });

  it('réinitialiser le mot de passe fait tomber TOUS les jetons', async () => {
    const u = await register();
    const jeton = await enregistrer(u.tokens.accessToken);
    const lien = `lien-${randomUUID()}`;
    await prisma.passwordReset.create({
      data: {
        userId: u.user.id,
        tokenHash: createHash('sha256').update(lien).digest('hex'),
        expiresAt: new Date(Date.now() + 600_000),
      },
    });

    await server()
      .post('/api/v1/auth/reset-password')
      .send({ token: lien, newPassword: 'NouveauMotDePasse42' })
      .expect(204);

    expect(await existe(jeton)).toBe(false);
  });

  it('un jeton antérieur au rattachement tombe à la première révocation du compte', async () => {
    const u = await register();
    const ancien = `jeton-ancien-${randomUUID()}`;
    await prisma.deviceToken.create({
      data: { userId: u.user.id, token: ancien, platform: 'IOS' },
    });

    await server().post('/api/v1/auth/logout').set(bearer(u.tokens.accessToken)).expect(204);

    expect(await existe(ancien)).toBe(false);
  });

  it('une session EXPIRÉE (inactivité) ne reçoit plus rien, même avant toute purge', async () => {
    const u = await register();
    const jeton = await enregistrer(u.tokens.accessToken);
    const repository = app.get(DeviceTokensRepository);
    expect(await repository.listTokens(u.user.id)).toEqual([jeton]);

    await prisma.userSession.updateMany({
      where: { userId: u.user.id },
      data: { expiresAt: new Date(Date.now() - 1_000) },
    });

    expect(await repository.listTokens(u.user.id)).toEqual([]);
  });

  it('suspendre un compte depuis l’administration supprime ses jetons', async () => {
    const u = await register();
    const jeton = await enregistrer(u.tokens.accessToken);
    await createAdminAccount(prisma, {
      email: adminEmail,
      password: ADMIN_PASSWORD,
      roleSlug: 'e2e-push-suspension',
      permissions: ['user:read', 'user:update'],
    });
    const admin = data<AdminLoginResult>(
      (
        await server()
          .post('/api/v1/admin/auth/login')
          .send({ email: adminEmail, password: ADMIN_PASSWORD })
          .expect(200)
      ).body,
    );

    await server()
      .patch(`/api/v1/admin/users/${u.user.id}/status`)
      .set(bearer(admin.accessToken))
      .send({ status: 'SUSPENDED' })
      .expect(200);

    expect(await existe(jeton)).toBe(false);
  });
});
