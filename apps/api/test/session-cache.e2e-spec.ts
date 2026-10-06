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
import { RedisService } from '../src/infrastructure/cache/redis.service';
import { SessionCache } from '../src/infrastructure/cache/session-cache';
import { reinitialiserDebit } from './support/throttle';

/**
 * Le cache des sessions du garde JWT, contre un VRAI Redis : il sert les
 * requêtes, et une révocation reste IMMÉDIATE — y compris quand un garde
 * relit la base juste avant elle et veut remettre l'entrée juste après.
 */
describe('Cache des sessions (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let cache: SessionCache;
  let redis: RedisService;
  const ids: string[] = [];
  const password = 'MotDePasseSolide42';

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const api = () => request(app.getHttpServer());
  const me = (token: string) =>
    api().get('/api/v1/users/me').set('Authorization', `Bearer ${token}`);

  const register = async (): Promise<AuthResult> => {
    const result = data<AuthResult>(
      (
        await api()
          .post('/api/v1/auth/register')
          .send({ email: `e2e-cache-${randomUUID()}@carlys.test`, password, displayName: 'Cache' })
          .expect(201)
      ).body,
    );
    ids.push(result.user.id);
    return result;
  };

  /** L'écriture du cache part sans être attendue : on la guette. */
  const enCache = async (userId: string, sessionId: string): Promise<boolean> => {
    for (let i = 0; i < 50; i += 1) {
      const cached = await cache.lookup(userId, sessionId);
      if (cached?.expiresAt != null) return true;
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    return false;
  };

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
    cache = app.get(SessionCache);
    redis = app.get(RedisService);
    await redis.ping();
  });

  beforeEach(() => reinitialiserDebit());

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: { in: ids } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('une requête authentifiée met la session en cache ; la suivante ne lit plus la base', async () => {
    const u = await register();
    const sid = (await prisma.userSession.findFirstOrThrow({ where: { userId: u.user.id } })).id;
    await me(u.tokens.accessToken).expect(200);
    expect(await enCache(u.user.id, sid)).toBe(true);

    // La base dit « révoquée » sans passer par l'application : le cache, lui,
    // sert encore — preuve qu'il est lu. (Les vraies révocations l'invalident.)
    await prisma.userSession.update({ where: { id: sid }, data: { revokedAt: new Date() } });
    await me(u.tokens.accessToken).expect(200);
    await cache.forget(u.user.id);
    await me(u.tokens.accessToken).expect(401);
  });

  it('déconnexion : l’access token en cache est refusé aussitôt', async () => {
    const u = await register();
    const sid = (await prisma.userSession.findFirstOrThrow({ where: { userId: u.user.id } })).id;
    await me(u.tokens.accessToken).expect(200);
    expect(await enCache(u.user.id, sid)).toBe(true);

    await api()
      .post('/api/v1/auth/logout')
      .set('Authorization', `Bearer ${u.tokens.accessToken}`)
      .expect(204);

    await me(u.tokens.accessToken).expect(401);
  });

  it('déconnexion des appareils : refusés AUSSITÔT, malgré le cache', async () => {
    const u = await register();
    const autre = data<AuthResult>(
      (
        await api()
          .post('/api/v1/auth/login')
          .send({ email: u.user.email, password, deviceName: 'Tablette' })
          .expect(200)
      ).body,
    );
    await me(autre.tokens.accessToken).expect(200);
    const sid = (
      await prisma.userSession.findFirstOrThrow({
        where: { userId: u.user.id, deviceName: 'Tablette' },
      })
    ).id;
    expect(await enCache(u.user.id, sid)).toBe(true);

    await api()
      .delete('/api/v1/auth/sessions')
      .set('Authorization', `Bearer ${u.tokens.accessToken}`)
      .expect(204);

    await me(autre.tokens.accessToken).expect(401);
    await me(u.tokens.accessToken).expect(200);
  });

  it('course : une remise en cache lue AVANT une révocation n’est pas écrite APRÈS elle', async () => {
    const userId = randomUUID();
    const sid = randomUUID();
    const expiresAt = new Date(Date.now() + 60_000);

    // Le garde lit la génération, puis la base (encore ouverte)…
    const lu = await cache.lookup(userId, sid);
    expect(lu).not.toBeNull();
    // …la révocation commit et invalide…
    await cache.forget(userId);
    // …et le garde veut retenir ce qu'il a lu : refusé.
    await cache.remember(userId, sid, expiresAt, lu?.generation ?? '');
    expect((await cache.lookup(userId, sid))?.expiresAt).toBeNull();

    // Une lecture POSTÉRIEURE à la révocation, elle, est retenue.
    const apres = await cache.lookup(userId, sid);
    await cache.remember(userId, sid, expiresAt, apres?.generation ?? '');
    expect((await cache.lookup(userId, sid))?.expiresAt).toBe(expiresAt.getTime());
    expect(await redis.getClient().ttl(`auth:sessions:${userId}`)).toBeLessThanOrEqual(30);
    await redis.getClient().del(`auth:sessions:${userId}`);
  });

  it('course avec une clé PERDUE (éviction, Redis redémarré) : toujours refusée', async () => {
    const userId = randomUUID();
    const sid = randomUUID();
    const lu = await cache.lookup(userId, sid);
    await cache.forget(userId);
    await redis.getClient().del(`auth:sessions:${userId}`);

    await cache.remember(userId, sid, new Date(Date.now() + 60_000), lu?.generation ?? '');
    expect((await cache.lookup(userId, sid))?.expiresAt).toBeNull();
    await redis.getClient().del(`auth:sessions:${userId}`);
  });

  it('suppression du compte : l’access token en cache est refusé aussitôt', async () => {
    const u = await register();
    const sid = (await prisma.userSession.findFirstOrThrow({ where: { userId: u.user.id } })).id;
    await me(u.tokens.accessToken).expect(200);
    expect(await enCache(u.user.id, sid)).toBe(true);

    await api()
      .delete('/api/v1/users/me')
      .set('Authorization', `Bearer ${u.tokens.accessToken}`)
      .send({ password })
      .expect(200);

    await me(u.tokens.accessToken).expect(401);
  });
});
