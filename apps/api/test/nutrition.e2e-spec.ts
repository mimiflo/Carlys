process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type MetabolismReport,
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

/**
 * Nutrition : profil métabolique complété pas à pas, rapport calculé côté
 * serveur uniquement, poids tiré de la dernière mesure corporelle.
 */
describe('Nutrition (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let accessToken: string;
  const userEmail = `e2e-nutrition-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

  const authed = () => ({
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${accessToken}`),
    patch: (url: string) =>
      request(app.getHttpServer()).patch(url).set('Authorization', `Bearer ${accessToken}`),
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${accessToken}`),
  });

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const response = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email: userEmail, password: 'MotDePasseSolide42', displayName: 'E2E' })
      .expect(201);
    accessToken = data<AuthResult>(response.body).tokens.accessToken;
  });

  afterAll(async () => {
    // Nettoyage strictement limité à cette suite (les e2e partagent la base).
    await prisma.user.deleteMany({ where: { email: userEmail } });
    await prisma.$disconnect();
    await app.close();
  });

  it('nouveau compte : rapport incomplet, champs manquants LISTÉS', async () => {
    const report = data<MetabolismReport>(
      (await authed().get('/api/v1/nutrition/metabolism').expect(200)).body,
    );

    expect(report.metabolism).toBeNull();
    expect(report.missing).toEqual(
      expect.arrayContaining(['sex', 'birthDate', 'heightCm', 'activityLevel', 'weightKg']),
    );
    await request(app.getHttpServer()).get('/api/v1/nutrition/metabolism').expect(401);
  });

  it('refuse une date de naissance future ou une taille aberrante', async () => {
    await authed()
      .patch('/api/v1/users/me')
      .send({ birthDate: '2030-01-01T00:00:00.000Z' })
      .expect(400);
    await authed().patch('/api/v1/users/me').send({ heightCm: 400 }).expect(400);
    await authed().patch('/api/v1/users/me').send({ sex: 'AUTRE' }).expect(400);
  });

  it('profil complété + poids mesuré → rapport calculé (valeurs Mifflin-St Jeor)', async () => {
    await authed()
      .patch('/api/v1/users/me')
      .send({
        sex: 'MALE',
        birthDate: '1996-01-15T00:00:00.000Z', // 30 ans au moment du test
        heightCm: 180,
        activityLevel: 'MODERATE',
        nutritionGoal: 'MAINTAIN',
      })
      .expect(200);

    await authed()
      .post('/api/v1/body-metrics')
      .send({
        id: randomUUID(),
        metricType: 'WEIGHT_KG',
        value: 80,
        measuredAt: new Date().toISOString(),
      })
      .expect(201);

    const report = data<MetabolismReport>(
      (await authed().get('/api/v1/nutrition/metabolism').expect(200)).body,
    );

    expect(report.missing).toEqual([]);
    expect(report.profile.weightKg).toBe(80);
    expect(report.profile.ageYears).toBe(30);
    // BMR : 10·80 + 6,25·180 − 5·30 + 5 = 1780 ; TDEE : ×1,55.
    expect(report.metabolism?.bmrKcal).toBe(1780);
    expect(report.metabolism?.tdeeKcal).toBe(2759);
    expect(report.metabolism?.targetKcal).toBe(2759);
    expect(report.metabolism?.proteinG).toBe(128);
    expect(report.metabolism?.bmiCategory).toBe('NORMAL');
    expect(report.metabolism?.waterMl).toBe(2800);
  });

  it('le rapport suit la DERNIÈRE mesure de poids', async () => {
    await authed()
      .post('/api/v1/body-metrics')
      .send({
        id: randomUUID(),
        metricType: 'WEIGHT_KG',
        value: 76,
        measuredAt: new Date().toISOString(),
      })
      .expect(201);

    const report = data<MetabolismReport>(
      (await authed().get('/api/v1/nutrition/metabolism').expect(200)).body,
    );

    expect(report.profile.weightKg).toBe(76);
    expect(report.metabolism?.waterMl).toBe(Math.round(35 * 76));
  });
});
