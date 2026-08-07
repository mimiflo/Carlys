process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type BodyMetric,
  type ExerciseProgression,
  type PersonalRecord,
  type ProgressOverview,
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
 * Progression : records recalculés à la clôture, statistiques par période,
 * mesures corporelles idempotentes. Toutes les vues sont privées.
 */
describe('Progression (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let accessToken: string;
  let otherAccessToken: string;
  let exerciseId: string;
  let exerciseName: string;
  const userEmail = `e2e-progression-${randomUUID()}@carlys.test`;
  const otherEmail = `e2e-progression-autre-${randomUUID()}@carlys.test`;

  const now = Date.now();
  const at = (minutesAgo: number): string => new Date(now - minutesAgo * 60_000).toISOString();

  const sessionA = randomUUID();
  const sessionB = randomUUID();
  const sessionC = randomUUID();
  const metricId = randomUUID();
  const oldMetricId = randomUUID();

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const register = (email: string) =>
      request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ email, password: 'MotDePasseSolide42', displayName: 'E2E' })
        .expect(201);

    accessToken = data<AuthResult>((await register(userEmail)).body).tokens.accessToken;
    otherAccessToken = data<AuthResult>((await register(otherEmail)).body).tokens.accessToken;

    const exercise = await prisma.exercise.findFirstOrThrow({ where: { isPublished: true } });
    exerciseId = exercise.id;
    exerciseName = exercise.name;
  });

  afterAll(async () => {
    // Nettoyage strictement limité à cette suite (les e2e partagent la base).
    await prisma.user.deleteMany({ where: { email: { in: [userEmail, otherEmail] } } });
    await prisma.$disconnect();
    await app.close();
  });

  const authed = (token: string) => ({
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${token}`),
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) =>
      request(app.getHttpServer()).delete(url).set('Authorization', `Bearer ${token}`),
  });

  const createSession = async (id: string, startedMinutesAgo: number): Promise<void> => {
    await authed(accessToken)
      .post('/api/v1/workout-sessions')
      .send({ id, startedAt: at(startedMinutesAgo) })
      .expect(201);
  };

  const addSet = async (
    sessionId: string,
    position: number,
    reps: number,
    weightKg: number,
    completedMinutesAgo: number,
  ): Promise<void> => {
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionId}/sets`)
      .send({
        id: randomUUID(),
        exerciseId,
        position,
        reps,
        weightKg,
        completedAt: at(completedMinutesAgo),
      })
      .expect(201);
  };

  it('crée les records à la clôture d’une première séance', async () => {
    await createSession(sessionA, 180);
    await addSet(sessionA, 0, 8, 60, 170); // volume 480
    await addSet(sessionA, 1, 12, 30, 160); // volume 360
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionA}/complete`)
      .send({ endedAt: at(120) }) // durée 3 600 s
      .expect(200);

    const records = data<PersonalRecord[]>(
      (await authed(accessToken).get('/api/v1/progress/records').expect(200)).body,
    );
    const byType = new Map(records.map((record) => [record.recordType, record]));
    expect(byType.get('MAX_WEIGHT')?.value).toBe(60);
    expect(byType.get('MAX_REPS')?.value).toBe(12);
    expect(byType.get('MAX_SET_VOLUME')?.value).toBe(480);
    expect(byType.get('MAX_WEIGHT')?.exerciseName).toBe(exerciseName);
  });

  it('ne remplace un record que s’il est battu', async () => {
    await createSession(sessionB, 90);
    await addSet(sessionB, 0, 10, 70, 80); // bat MAX_WEIGHT (70) et MAX_SET_VOLUME (700), pas MAX_REPS
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionB}/complete`)
      .send({ endedAt: at(60) }) // durée 1 800 s
      .expect(200);

    const records = data<PersonalRecord[]>(
      (await authed(accessToken).get('/api/v1/progress/records').expect(200)).body,
    );
    const byType = new Map(records.map((record) => [record.recordType, record]));
    expect(byType.get('MAX_WEIGHT')?.value).toBe(70);
    expect(byType.get('MAX_SET_VOLUME')?.value).toBe(700);
    expect(byType.get('MAX_REPS')?.value).toBe(12); // inchangé
  });

  it('une séance abandonnée ne touche pas aux records', async () => {
    await createSession(sessionC, 50);
    await addSet(sessionC, 0, 20, 100, 45);
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionC}/abandon`)
      .send({})
      .expect(200);

    const records = data<PersonalRecord[]>(
      (await authed(accessToken).get('/api/v1/progress/records').expect(200)).body,
    );
    const byType = new Map(records.map((record) => [record.recordType, record]));
    expect(byType.get('MAX_WEIGHT')?.value).toBe(70);
  });

  it('agrège la période : totaux et volume par intervalle', async () => {
    const overview = data<ProgressOverview>(
      (await authed(accessToken).get('/api/v1/progress/overview?period=week').expect(200)).body,
    );

    expect(overview.period).toBe('week');
    expect(overview.sessionsCount).toBe(2); // la séance abandonnée est exclue
    expect(overview.setsCount).toBe(3);
    expect(overview.totalVolumeKg).toBe(480 + 360 + 700);
    expect(overview.totalDurationSeconds).toBe(3_600 + 1_800);
    expect(overview.points.length).toBeGreaterThan(0);
    const bucketVolume = overview.points.reduce((sum, point) => sum + point.volumeKg, 0);
    expect(bucketVolume).toBe(overview.totalVolumeKg);

    // Les trois périodes répondent avec la même enveloppe.
    for (const period of ['month', 'year'] as const) {
      const other = data<ProgressOverview>(
        (await authed(accessToken).get(`/api/v1/progress/overview?period=${period}`).expect(200))
          .body,
      );
      expect(other.period).toBe(period);
      expect(other.sessionsCount).toBe(2);
    }
    await authed(accessToken).get('/api/v1/progress/overview?period=decade').expect(400);
  });

  it('trace la progression sur un exercice du catalogue', async () => {
    const progression = data<ExerciseProgression>(
      (await authed(accessToken).get(`/api/v1/progress/exercises/${exerciseId}`).expect(200)).body,
    );

    expect(progression.exerciseName).toBe(exerciseName);
    expect(progression.points).toHaveLength(2); // séances terminées uniquement
    expect(progression.points[0]?.maxWeightKg).toBe(60);
    expect(progression.points[1]?.maxWeightKg).toBe(70);
    expect(progression.records.find((record) => record.recordType === 'MAX_WEIGHT')?.value).toBe(
      70,
    );

    await authed(accessToken).get(`/api/v1/progress/exercises/${randomUUID()}`).expect(404);
  });

  it('la progression d’autrui reste invisible', async () => {
    const records = data<PersonalRecord[]>(
      (await authed(otherAccessToken).get('/api/v1/progress/records').expect(200)).body,
    );
    expect(records).toHaveLength(0);

    const overview = data<ProgressOverview>(
      (await authed(otherAccessToken).get('/api/v1/progress/overview').expect(200)).body,
    );
    expect(overview.sessionsCount).toBe(0);

    await request(app.getHttpServer()).get('/api/v1/progress/overview').expect(401);
  });

  it('enregistre une mesure corporelle et REJOUE la création sans doublon', async () => {
    const payload = {
      id: metricId,
      metricType: 'WEIGHT_KG',
      value: 82.5,
      measuredAt: at(60),
    };

    const first = await authed(accessToken).post('/api/v1/body-metrics').send(payload).expect(201);
    expect(data<BodyMetric>(first.body).value).toBe(82.5);

    await authed(accessToken).post('/api/v1/body-metrics').send(payload).expect(201);
    const count = await prisma.bodyMetric.count({ where: { id: metricId } });
    expect(count).toBe(1);

    // Le même id revendiqué par un autre utilisateur est un conflit.
    await authed(otherAccessToken).post('/api/v1/body-metrics').send(payload).expect(409);

    // Valeur hors bornes refusée.
    await authed(accessToken)
      .post('/api/v1/body-metrics')
      .send({ ...payload, id: randomUUID(), value: 5_000 })
      .expect(400);
  });

  it('liste les mesures du plus ancien au plus récent, par type', async () => {
    await authed(accessToken)
      .post('/api/v1/body-metrics')
      .send({
        id: oldMetricId,
        metricType: 'WEIGHT_KG',
        value: 84,
        measuredAt: at(60 * 24 * 10), // il y a 10 jours
      })
      .expect(201);

    const metrics = data<BodyMetric[]>(
      (await authed(accessToken).get('/api/v1/body-metrics').expect(200)).body,
    );
    expect(metrics.map((metric) => metric.id)).toEqual([oldMetricId, metricId]);

    const fat = data<BodyMetric[]>(
      (
        await authed(accessToken)
          .get('/api/v1/body-metrics?metricType=BODY_FAT_PERCENT')
          .expect(200)
      ).body,
    );
    expect(fat).toHaveLength(0);

    // Invisible pour un autre utilisateur.
    const others = data<BodyMetric[]>(
      (await authed(otherAccessToken).get('/api/v1/body-metrics').expect(200)).body,
    );
    expect(others).toHaveLength(0);
  });

  it('supprime une mesure (suppression logique rejouable)', async () => {
    await authed(accessToken).delete(`/api/v1/body-metrics/${oldMetricId}`).expect(204);
    await authed(accessToken).delete(`/api/v1/body-metrics/${oldMetricId}`).expect(204);

    const metrics = data<BodyMetric[]>(
      (await authed(accessToken).get('/api/v1/body-metrics').expect(200)).body,
    );
    expect(metrics.map((metric) => metric.id)).toEqual([metricId]);

    // La mesure d'autrui reste invisible, même à la suppression.
    await authed(otherAccessToken).delete(`/api/v1/body-metrics/${metricId}`).expect(404);
  });
});
