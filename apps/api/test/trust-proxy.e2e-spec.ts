process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import { type ApiSuccessEnvelope, type AuthResult, type AuthSession } from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { AppConfigService } from '../src/config/app-config.service';
import { type Env } from '../src/config/env.schema';

/**
 * Adresse du client derrière un reverse proxy.
 *
 * Le throttler, le verrouillage et l'audit lisent tous `request.ip`. Sans
 * saut de confiance, c'est l'adresse de la socket, quoi qu'annonce
 * X-Forwarded-For ; avec un saut, c'est la dernière adresse de
 * X-Forwarded-For — celle que le proxy ajoute lui-même, jamais celle que le
 * client aurait forgée.
 */
describe('Trust proxy (e2e)', () => {
  const FORWARDED_IP = '203.0.113.9';
  const emails: string[] = [];
  let prisma: PrismaClient;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

  /**
   * Sans argument : la configuration réelle (donc le défaut, 0 saut). Avec :
   * la configuration est figée à l'import du module, on la substitue pour ce
   * seul réglage, comme le fait la suite du coach pour son interrupteur.
   */
  async function buildApp(hops?: number): Promise<INestApplication<App>> {
    let builder = Test.createTestingModule({ imports: [AppModule] });
    if (hops !== undefined) {
      builder = builder.overrideProvider(AppConfigService).useFactory({
        inject: [ConfigService],
        factory: (config: ConfigService<Env, true>) =>
          Object.create(new AppConfigService(config), {
            trustProxyHops: { get: () => hops },
          }) as AppConfigService,
      });
    }
    const moduleFixture = await builder.compile();
    const app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app);
    await app.init();
    return app;
  }

  /**
   * Inscrit un appareil en annonçant une adresse forgée, puis lit l'adresse
   * que l'API a réellement retenue pour la session ouverte.
   */
  async function observedIp(app: INestApplication<App>): Promise<string | null> {
    const email = `e2e-proxy-${randomUUID()}@carlys.test`;
    emails.push(email);

    const registered = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .set('X-Forwarded-For', FORWARDED_IP)
      .send({ email, password: 'MotDePasseSolide42', displayName: 'Proxy' })
      .expect(201);
    const { accessToken } = data<AuthResult>(registered.body).tokens;

    const sessions = await request(app.getHttpServer())
      .get('/api/v1/auth/sessions')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    return data<AuthSession[]>(sessions.body).find((session) => session.current)?.ipAddress ?? null;
  }

  beforeAll(() => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
    await prisma.$disconnect();
  });

  it('sans saut de confiance (le défaut), X-Forwarded-For est ignoré : la socket fait foi', async () => {
    const app = await buildApp();
    try {
      const ip = await observedIp(app);
      expect(ip).not.toBe(FORWARDED_IP);
      expect(ip).toMatch(/127\.0\.0\.1|::1/);
    } finally {
      await app.close();
    }
  });

  it('avec un saut de confiance, X-Forwarded-For fait foi', async () => {
    const app = await buildApp(1);
    try {
      expect(await observedIp(app)).toBe(FORWARDED_IP);
    } finally {
      await app.close();
    }
  });
});
