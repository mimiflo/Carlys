process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiErrorEnvelope,
  type ApiSuccessEnvelope,
  type AuthResult,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { Redis } from 'ioredis';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { EmailService } from '../src/infrastructure/email/email.service';
import { reauthLockoutKey } from '../src/modules/auth/application/reauthentication.service';
import { reinitialiserDebit } from './support/throttle';

const PASSWORD = 'MotDePasseSolide42';
/** AUTH_MAX_LOGIN_ATTEMPTS par défaut. */
const SEUIL = 5;

/**
 * Durcissement des routes qui vérifient un mot de passe ou envoient un
 * courrier à la demande d'une session : plafonds PAR COMPTE (verrouillage des
 * re-authentifications, cadence des liens de vérification) et limites par IP.
 */
describe('Authentification — oracles et envois bornés (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let redis: Redis;
  const emails: string[] = [];
  const userIds: string[] = [];
  const liensEnvoyes: string[] = [];

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const errorOf = (body: unknown): ApiErrorEnvelope['error'] => (body as ApiErrorEnvelope).error;
  const server = () => request(app.getHttpServer());

  const register = async (name: string): Promise<AuthResult & { email: string }> => {
    const email = `e2e-auth-surete-${name}-${randomUUID()}@carlys.test`;
    emails.push(email);
    const res = await server()
      .post('/api/v1/auth/register')
      .send({ email, password: PASSWORD, displayName: name })
      .expect(201);
    const result = data<AuthResult>(res.body);
    userIds.push(result.user.id);
    return { ...result, email };
  };
  const changePassword = (token: string, currentPassword: string) =>
    server()
      .post('/api/v1/auth/change-password')
      .set('Authorization', `Bearer ${token}`)
      .send({ currentPassword, newPassword: 'NouveauMotDePasse42' });
  const deleteMe = (token: string, password: string) =>
    server().delete('/api/v1/users/me').set('Authorization', `Bearer ${token}`).send({ password });
  const resend = (token: string) =>
    server().post('/api/v1/auth/resend-verification').set('Authorization', `Bearer ${token}`);

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
    // Le lien part dans un e-mail : on le capte au passage, sans rien envoyer.
    jest
      .spyOn(app.get(EmailService), 'sendEmailVerification')
      .mockImplementation((_to: string, token: string) => {
        liensEnvoyes.push(token);
      });
  });

  beforeEach(reinitialiserDebit);

  afterAll(async () => {
    await app.close();
    for (const id of userIds) {
      await redis.del(`auth:lockout:${reauthLockoutKey(id)}`);
    }
    await redis.quit();
    await prisma.user.deleteMany({ where: { id: { in: userIds } } });
    await prisma.$disconnect();
  });

  it('change-password : 429 au plus tard au 6e mauvais essai, même avec le bon mot de passe ensuite', async () => {
    const u = await register('change');
    const statuts: number[] = [];
    for (let i = 0; i <= SEUIL; i += 1) {
      statuts.push((await changePassword(u.tokens.accessToken, `Faux-${i}-motdepasse`)).status);
    }
    expect(statuts).toEqual([401, 401, 401, 401, 401, 429]);

    // Verrouillé : même le bon mot de passe ne change rien et ne dit rien.
    const juste = await changePassword(u.tokens.accessToken, PASSWORD);
    expect(juste.status).toBe(429);
    expect(errorOf(juste.body).code).toBe('RATE_LIMITED');

    // La CONNEXION du propriétaire reste ouverte : compteur distinct.
    await server()
      .post('/api/v1/auth/login')
      .send({ email: u.email, password: PASSWORD })
      .expect(200);
  });

  it('DELETE /users/me : même verrouillage, et le compte n’est pas supprimé', async () => {
    const u = await register('suppr');
    const statuts: number[] = [];
    for (let i = 0; i <= SEUIL; i += 1) {
      statuts.push((await deleteMe(u.tokens.accessToken, `Faux-${i}-motdepasse`)).status);
    }
    expect(statuts).toEqual([401, 401, 401, 401, 401, 429]);
    await deleteMe(u.tokens.accessToken, PASSWORD).expect(429);
    const user = await prisma.user.findUniqueOrThrow({ where: { id: u.user.id } });
    expect(user.status).toBe('ACTIVE');
  });

  it('un succès remet le compteur à zéro', async () => {
    const u = await register('succes');
    for (let i = 0; i < SEUIL - 1; i += 1) {
      await changePassword(u.tokens.accessToken, `Faux-${i}-motdepasse`).expect(401);
    }
    await changePassword(u.tokens.accessToken, PASSWORD).expect(204);
    expect(await redis.get(`auth:lockout:${reauthLockoutKey(u.user.id)}`)).toBeNull();
  });

  it('change-password : limite par IP au-delà de 10 requêtes par minute, tous comptes confondus', async () => {
    const comptes = [await register('ip-a'), await register('ip-b'), await register('ip-c')];
    await reinitialiserDebit();
    const statuts: number[] = [];
    // 4 + 4 + 3 essais : aucun compte n'atteint son propre seuil.
    for (const [index, essais] of [4, 4, 3].entries()) {
      const compte = comptes[index];
      if (compte === undefined) {
        throw new Error('compte manquant');
      }
      for (let i = 0; i < essais; i += 1) {
        statuts.push((await changePassword(compte.tokens.accessToken, `Faux-${i}-x`)).status);
      }
    }
    expect(statuts.slice(0, 10).every((statut) => statut === 401)).toBe(true);
    expect(statuts[10]).toBe(429);
  });

  it('resend-verification : un lien par minute au plus, cinq par jour, seul le dernier vaut', async () => {
    const u = await register('renvoi');
    const token = u.tokens.accessToken;
    const lignes = () => prisma.emailVerification.findMany({ where: { userId: u.user.id } });
    const avant = liensEnvoyes.length;

    // Juste après l'inscription : délai minimal, rien ne part, réponse identique.
    await resend(token).expect(204);
    await resend(token).expect(204);
    expect(await lignes()).toHaveLength(1);
    expect(liensEnvoyes.length).toBe(avant);

    // Une fois le délai passé, un nouveau lien part et invalide le premier.
    await prisma.emailVerification.updateMany({
      where: { userId: u.user.id },
      data: { createdAt: new Date(Date.now() - 120_000) },
    });
    const premier = liensEnvoyes.at(-1);
    await resend(token).expect(204);
    const apres = await lignes();
    expect(apres).toHaveLength(2);
    expect(apres.filter((ligne) => ligne.usedAt === null)).toHaveLength(1);
    expect(liensEnvoyes.length).toBe(avant + 1);
    if (premier !== undefined) {
      await server().post('/api/v1/auth/verify-email').send({ token: premier }).expect(401);
    }

    // Plafond de 5 liens sur 24 h, délai minimal passé ou non.
    await reinitialiserDebit();
    await prisma.emailVerification.createMany({
      data: [1, 2, 3].map((i) => ({
        userId: u.user.id,
        tokenHash: `e2e-plafond-${randomUUID()}-${i}`,
        expiresAt: new Date(Date.now() + 3_600_000),
        createdAt: new Date(Date.now() - 3_600_000),
      })),
    });
    await prisma.emailVerification.updateMany({
      where: { userId: u.user.id },
      data: { createdAt: new Date(Date.now() - 3_600_000) },
    });
    await resend(token).expect(204);
    expect(await lignes()).toHaveLength(5);
    expect(liensEnvoyes.length).toBe(avant + 1);
  });

  it('resend-verification : 3 appels par 10 minutes et par IP', async () => {
    const u = await register('renvoi-ip');
    const statuts: number[] = [];
    for (let i = 0; i < 4; i += 1) {
      statuts.push((await resend(u.tokens.accessToken)).status);
    }
    expect(statuts).toEqual([204, 204, 204, 429]);
  });
});
