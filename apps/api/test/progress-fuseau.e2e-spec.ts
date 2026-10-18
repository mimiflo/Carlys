process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type LifetimeStats,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { ProgressRepository } from '../src/modules/progress/infrastructure/progress.repository';

/**
 * Le découpage par jour et par semaine se fait dans le FUSEAU de la
 * personne. `startedAt` est un horodatage SANS fuseau qui porte de l'UTC :
 * le lire comme une heure locale décalait d'autant, dans le mauvais sens
 * (signalé le 18 octobre 2026). Le fuseau par défaut des comptes est
 * Europe/Paris : toute séance de la fin de soirée tombait la veille.
 */
describe('Progression : découpage dans le fuseau de la personne (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let accessToken: string;
  let userId: string;
  const email = `e2e-fuseau-${randomUUID()}@carlys.test`;
  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

  // Dimanche 11 octobre 2026, 22 h 30 UTC = LUNDI 12 octobre, 0 h 30 à Paris.
  const startedAt = new Date('2026-10-11T22:30:00.000Z');

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const auth = data<AuthResult>(
      (
        await request(app.getHttpServer())
          .post('/api/v1/auth/register')
          .send({ email, password: 'MotDePasseSolide42', displayName: 'E2E' })
          .expect(201)
      ).body,
    );
    accessToken = auth.tokens.accessToken;
    userId = auth.user.id;
    await prisma.userProfile.update({ where: { userId }, data: { timezone: 'Europe/Paris' } });
    await prisma.workoutSession.create({
      data: {
        id: randomUUID(),
        userId,
        status: 'COMPLETED',
        startedAt,
        endedAt: new Date(startedAt.getTime() + 45 * 60_000),
        durationSeconds: 45 * 60,
      },
    });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email } });
    await prisma.$disconnect();
    await app.close();
  });

  it('une séance du lundi 0 h 30 à Paris compte dans la semaine du LUNDI', async () => {
    const lifetime = data<LifetimeStats>(
      (
        await request(app.getHttpServer())
          .get('/api/v1/progress/lifetime')
          .set('Authorization', `Bearer ${accessToken}`)
          .expect(200)
      ).body,
    );
    expect(lifetime.weeks).toEqual([{ mondayOn: '2026-10-12', sessions: 1 }]);
  });

  it('et dans la JOURNÉE du lundi : le panier commence à minuit à Paris', async () => {
    const buckets = await app
      .get(ProgressRepository)
      .volumeBuckets(
        userId,
        new Date('2026-10-01T00:00:00.000Z'),
        new Date('2026-10-31T00:00:00.000Z'),
        'week',
        'Europe/Paris',
      );
    // Minuit du lundi 12 à Paris (UTC+2 en octobre) = dimanche 11, 22 h UTC.
    expect(buckets.map((bucket) => bucket.bucketStart.toISOString())).toEqual([
      '2026-10-11T22:00:00.000Z',
    ]);
  });
});
