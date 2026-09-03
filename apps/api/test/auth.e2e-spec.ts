process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiErrorEnvelope,
  type ApiSuccessEnvelope,
  type AuthResult,
  type AuthSession,
  type AuthTokens,
  type AuthUser,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';

/**
 * Parcours critiques de l'authentification, contre une vraie base PostgreSQL
 * (migrations appliquées au préalable : pnpm prisma:migrate:deploy).
 * Redis peut être absent : le verrouillage passe alors en fail-open.
 */
describe('Authentification (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  const password = 'MotDePasseSolide42';
  const email = `e2e-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const errorOf = (body: unknown): ApiErrorEnvelope['error'] => (body as ApiErrorEnvelope).error;
  const sha256 = (value: string): string => createHash('sha256').update(value).digest('hex');

  beforeAll(async () => {
    prisma = new PrismaClient({
      datasourceUrl: process.env.DATABASE_URL,
    });
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
  });

  /** Comptes créés par la suite : le supprimé ne porte plus `email`, on le retrouve par id. */
  const createdUserIds: string[] = [];

  afterAll(async () => {
    // Nettoyage strictement limité à cette suite (les e2e partagent la base).
    await prisma.user.deleteMany({ where: { OR: [{ email }, { id: { in: createdUserIds } }] } });
    await prisma.$disconnect();
    await app.close();
  });

  const api = () => request(app.getHttpServer());

  it('refuse une inscription invalide avec une enveloppe VALIDATION_ERROR', async () => {
    const response = await api()
      .post('/api/v1/auth/register')
      .send({ email: 'pas-un-email', password: 'court', displayName: '' })
      .expect(400);

    const error = errorOf(response.body);
    expect(error.code).toBe('VALIDATION_ERROR');
    expect(error.details.length).toBeGreaterThan(0);
  });

  let firstSession: AuthTokens;

  it('inscrit un utilisateur et ouvre une session', async () => {
    const response = await api()
      .post('/api/v1/auth/register')
      .send({ email, password, displayName: 'E2E', deviceName: 'Appareil A' })
      .expect(201);

    const result = data<AuthResult>(response.body);
    expect(result.user.email).toBe(email);
    expect(result.user.emailVerified).toBe(false);
    expect(result.tokens.accessToken.length).toBeGreaterThan(20);
    firstSession = result.tokens;

    const verification = await prisma.emailVerification.findFirst({
      where: { user: { email } },
    });
    expect(verification).not.toBeNull();
  });

  it('refuse un double compte sur le même e-mail (insensible à la casse)', async () => {
    const response = await api()
      .post('/api/v1/auth/register')
      .send({ email: email.toUpperCase(), password, displayName: 'E2E' })
      .expect(409);
    expect(errorOf(response.body).code).toBe('CONFLICT');
  });

  it('protège /users/me et le sert avec un access token valide', async () => {
    await api().get('/api/v1/users/me').expect(401);

    const response = await api()
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${firstSession.accessToken}`)
      .expect(200);
    expect(data<AuthUser>(response.body).email).toBe(email);
    // Pas encore d'identité choisie : null, jamais un défaut imposé.
    expect(data<AuthUser>(response.body).carlysProfile).toBeNull();
  });

  it('choisit un profil Carlys — modifiable, jamais un niveau imposé', async () => {
    const chosen = await api()
      .patch('/api/v1/users/me')
      .set('Authorization', `Bearer ${firstSession.accessToken}`)
      .send({ carlysProfile: 'STRATEGE' })
      .expect(200);
    expect(data<AuthUser>(chosen.body).carlysProfile).toBe('STRATEGE');

    // On peut évoluer d'un profil à l'autre à tout moment.
    const changed = await api()
      .patch('/api/v1/users/me')
      .set('Authorization', `Bearer ${firstSession.accessToken}`)
      .send({ carlysProfile: 'CHALLENGER' })
      .expect(200);
    expect(data<AuthUser>(changed.body).carlysProfile).toBe('CHALLENGER');

    // Une valeur hors des quatre profils est refusée.
    await api()
      .patch('/api/v1/users/me')
      .set('Authorization', `Bearer ${firstSession.accessToken}`)
      .send({ carlysProfile: 'GUERRIER' })
      .expect(400);
  });

  it('refuse un mot de passe erroné avec un message générique', async () => {
    const response = await api()
      .post('/api/v1/auth/login')
      .send({ email, password: 'MauvaisMotDePasse1' })
      .expect(401);
    expect(errorOf(response.body).message).toBe('E-mail ou mot de passe incorrect.');
  });

  let secondSession: AuthTokens;

  it('connecte, puis fait tourner le refresh token', async () => {
    const login = await api()
      .post('/api/v1/auth/login')
      .send({ email, password, deviceName: 'Appareil B' })
      .expect(200);
    secondSession = data<AuthResult>(login.body).tokens;

    const refreshed = await api()
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: secondSession.refreshToken })
      .expect(200);
    const rotated = data<AuthTokens>(refreshed.body);
    expect(rotated.refreshToken).not.toBe(secondSession.refreshToken);

    // Réutiliser l'ancien jeton = réutilisation détectée → session révoquée.
    await api()
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: secondSession.refreshToken })
      .expect(401);

    // Le jeton pourtant « neuf » de la même session tombe aussi…
    await api()
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: rotated.refreshToken })
      .expect(401);

    // …et l'access token de la session révoquée est immédiatement invalide.
    await api()
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${rotated.accessToken}`)
      .expect(401);

    const reuseAudit = await prisma.auditLog.findFirst({
      where: { action: 'auth.refresh_reuse_detected', user: { email } },
    });
    expect(reuseAudit).not.toBeNull();
  });

  it('liste les appareils et révoque une session ciblée', async () => {
    const login = await api()
      .post('/api/v1/auth/login')
      .send({ email, password, deviceName: 'Appareil C' })
      .expect(200);
    const tokens = data<AuthResult>(login.body).tokens;

    const list = await api()
      .get('/api/v1/auth/sessions')
      .set('Authorization', `Bearer ${tokens.accessToken}`)
      .expect(200);
    const sessions = data<AuthSession[]>(list.body);
    expect(sessions.length).toBeGreaterThanOrEqual(2);
    expect(sessions.filter((session) => session.current)).toHaveLength(1);

    const other = sessions.find((session) => !session.current);
    expect(other).toBeDefined();
    await api()
      .delete(`/api/v1/auth/sessions/${other?.id ?? ''}`)
      .set('Authorization', `Bearer ${tokens.accessToken}`)
      .expect(204);

    // La session « Appareil A » révoquée ne peut plus rafraîchir.
    await api()
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: firstSession.refreshToken })
      .expect(401);
  });

  it('vérifie l’adresse e-mail via un jeton', async () => {
    const user = await prisma.user.findUniqueOrThrow({ where: { email } });
    const rawToken = randomBytes(32).toString('base64url');
    await prisma.emailVerification.create({
      data: {
        userId: user.id,
        tokenHash: sha256(rawToken),
        expiresAt: new Date(Date.now() + 3_600_000),
      },
    });

    await api().post('/api/v1/auth/verify-email').send({ token: rawToken }).expect(204);
    await api().post('/api/v1/auth/verify-email').send({ token: rawToken }).expect(401);

    const refreshed = await prisma.user.findUniqueOrThrow({ where: { email } });
    expect(refreshed.emailVerifiedAt).not.toBeNull();
  });

  it('réinitialise le mot de passe et révoque toutes les sessions', async () => {
    await api().post('/api/v1/auth/forgot-password').send({ email }).expect(202);
    await api()
      .post('/api/v1/auth/forgot-password')
      .send({ email: `inconnu-${randomUUID()}@carlys.test` })
      .expect(202);

    const user = await prisma.user.findUniqueOrThrow({ where: { email } });
    const rawToken = randomBytes(32).toString('base64url');
    await prisma.passwordReset.create({
      data: {
        userId: user.id,
        tokenHash: sha256(rawToken),
        expiresAt: new Date(Date.now() + 600_000),
      },
    });

    const newPassword = 'NouveauMotDePasse42';
    await api()
      .post('/api/v1/auth/reset-password')
      .send({ token: rawToken, newPassword })
      .expect(204);

    await api().post('/api/v1/auth/login').send({ email, password }).expect(401);
    const login = await api()
      .post('/api/v1/auth/login')
      .send({ email, password: newPassword })
      .expect(200);

    const active = await prisma.userSession.findMany({
      where: { userId: user.id, revokedAt: null },
    });
    expect(active).toHaveLength(1);

    // Remet le mot de passe d'origine pour la suite.
    const tokens = data<AuthResult>(login.body).tokens;
    await api()
      .post('/api/v1/auth/change-password')
      .set('Authorization', `Bearer ${tokens.accessToken}`)
      .send({ currentPassword: newPassword, newPassword: password })
      .expect(204);
  });

  let deletedUserId: string;

  it('supprime le compte avec confirmation par mot de passe, et libère l’identité', async () => {
    const login = await api().post('/api/v1/auth/login').send({ email, password }).expect(200);
    const tokens = data<AuthResult>(login.body).tokens;
    const auth = `Bearer ${tokens.accessToken}`;

    const before = await prisma.user.findUniqueOrThrow({ where: { email } });
    deletedUserId = before.id;
    createdUserIds.push(before.id);
    // Un jeton d'appareil et des données de profil personnelles : tout doit partir avec le compte.
    await api()
      .post('/api/v1/notifications/device-tokens')
      .set('Authorization', auth)
      .send({ token: `e2e-jeton-${randomUUID()}`, platform: 'ANDROID' })
      .expect(204);
    await prisma.userProfile.update({
      where: { userId: before.id },
      data: { heightCm: 180, sex: 'MALE', birthDate: new Date('1990-01-01T00:00:00Z') },
    });

    await api()
      .delete('/api/v1/users/me')
      .set('Authorization', auth)
      .send({ password: 'MauvaisMotDePasse1' })
      .expect(401);

    await api()
      .delete('/api/v1/users/me')
      .set('Authorization', auth)
      .send({ password })
      .expect(204);

    await api().post('/api/v1/auth/login').send({ email, password }).expect(401);

    // La ligne supprimée ne porte plus l'adresse d'origine, ni rien qui identifie la personne.
    expect(await prisma.user.findUnique({ where: { email } })).toBeNull();
    const deleted = await prisma.user.findUniqueOrThrow({
      where: { id: before.id },
      include: { profile: true, deviceTokens: true, sessions: true },
    });
    expect(deleted.status).toBe('DELETED');
    expect(deleted.deletedAt).not.toBeNull();
    expect(deleted.email).toBe(`supprime+${before.id}@carlys.invalid`);
    expect(deleted.friendCode).not.toBe(before.friendCode);
    expect(deleted.profile?.displayName).toBe('');
    expect(deleted.profile?.heightCm).toBeNull();
    expect(deleted.profile?.sex).toBeNull();
    expect(deleted.profile?.birthDate).toBeNull();
    expect(deleted.deviceTokens).toHaveLength(0);
    expect(deleted.sessions.length).toBeGreaterThan(0);
    expect(deleted.sessions.every((session) => session.revokedAt !== null)).toBe(true);
  });

  it('après suppression, la même adresse se réinscrit (201) : un compte neuf, pas l’ancien', async () => {
    const response = await api()
      .post('/api/v1/auth/register')
      .send({ email, password, displayName: 'E2E bis' })
      .expect(201);

    const result = data<AuthResult>(response.body);
    expect(result.user.email).toBe(email);
    expect(result.user.id).not.toBe(deletedUserId);
    createdUserIds.push(result.user.id);
  });
});
