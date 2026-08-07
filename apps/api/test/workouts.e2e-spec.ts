process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type CursorPaginationMeta,
  type WorkoutSessionDetail,
  type WorkoutSessionSummary,
  type WorkoutSet,
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
import { ensureExerciseFixture } from './support/exercise-fixture';

/**
 * Séances offline-first : chaque écriture est REJOUÉE pour vérifier
 * l'idempotence (aucun doublon, même état renvoyé).
 */
describe('Séances (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let accessToken: string;
  let otherAccessToken: string;
  const userEmail = `e2e-seances-${randomUUID()}@carlys.test`;
  const otherEmail = `e2e-seances-autre-${randomUUID()}@carlys.test`;

  const sessionId = randomUUID();
  const setId = randomUUID();

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
  });

  afterAll(async () => {
    // Nettoyage strictement limité à cette suite (les e2e partagent la base).
    await prisma.user.deleteMany({ where: { email: { in: [userEmail, otherEmail] } } });
    await prisma.exercise.deleteMany({ where: { slug: 'e2e-workouts-exercice' } });
    await prisma.$disconnect();
    await app.close();
  });

  const authed = (token: string) => ({
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${token}`),
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${token}`),
    patch: (url: string) =>
      request(app.getHttpServer()).patch(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) =>
      request(app.getHttpServer()).delete(url).set('Authorization', `Bearer ${token}`),
  });

  it('crée une séance et REJOUE la création sans doublon', async () => {
    const payload = {
      id: sessionId,
      name: 'Push A',
      startedAt: '2026-08-07T10:00:00.000Z',
    };

    const first = await authed(accessToken)
      .post('/api/v1/workout-sessions')
      .send(payload)
      .expect(201);
    expect(data<WorkoutSessionDetail>(first.body).id).toBe(sessionId);

    const replay = await authed(accessToken)
      .post('/api/v1/workout-sessions')
      .send(payload)
      .expect(201);
    expect(data<WorkoutSessionDetail>(replay.body).id).toBe(sessionId);

    const count = await prisma.workoutSession.count({ where: { id: sessionId } });
    expect(count).toBe(1);
  });

  it('ajoute une série depuis le catalogue et REJOUE l’ajout sans doublon', async () => {
    // Fixture dédiée : la suite ne dépend jamais du seed (base CI vierge).
    const exercise = await ensureExerciseFixture(prisma, 'e2e-workouts-exercice');
    const payload = {
      id: setId,
      exerciseId: exercise.id,
      position: 0,
      reps: 10,
      weightKg: 62.5,
      restSeconds: 90,
      completedAt: '2026-08-07T10:05:00.000Z',
    };

    const first = await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionId}/sets`)
      .send(payload)
      .expect(201);
    const set = data<WorkoutSet>(first.body);
    expect(set.exerciseName).toBe(exercise.name);
    expect(set.weightKg).toBe(62.5);

    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionId}/sets`)
      .send(payload)
      .expect(201);

    const count = await prisma.workoutSet.count({ where: { id: setId } });
    expect(count).toBe(1);
  });

  it('refuse une série sans exercice résolvable et une charge aberrante', async () => {
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionId}/sets`)
      .send({
        id: randomUUID(),
        position: 1,
        reps: 8,
        completedAt: '2026-08-07T10:06:00.000Z',
      })
      .expect(400);

    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionId}/sets`)
      .send({
        id: randomUUID(),
        exerciseName: 'Exercice libre',
        position: 1,
        weightKg: 5_000,
        completedAt: '2026-08-07T10:06:00.000Z',
      })
      .expect(400);
  });

  it('corrige puis supprime une série (suppression rejouable)', async () => {
    const patched = await authed(accessToken)
      .patch(`/api/v1/workout-sets/${setId}`)
      .send({ reps: 12 })
      .expect(200);
    expect(data<WorkoutSet>(patched.body).reps).toBe(12);

    await authed(accessToken).delete(`/api/v1/workout-sets/${setId}`).expect(204);
    await authed(accessToken).delete(`/api/v1/workout-sets/${setId}`).expect(204);

    const detail = await authed(accessToken)
      .get(`/api/v1/workout-sessions/${sessionId}`)
      .expect(200);
    expect(data<WorkoutSessionDetail>(detail.body).sets).toHaveLength(0);
  });

  it('termine la séance et REJOUE la clôture ; l’abandon croisé est un conflit', async () => {
    const payload = { endedAt: '2026-08-07T11:00:00.000Z' };

    const completed = await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionId}/complete`)
      .send(payload)
      .expect(200);
    const session = data<WorkoutSessionDetail>(completed.body);
    expect(session.status).toBe('COMPLETED');
    expect(session.durationSeconds).toBe(3_600);

    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionId}/complete`)
      .send(payload)
      .expect(200);

    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${sessionId}/abandon`)
      .send({})
      .expect(409);
  });

  it('liste l’historique paginé, invisible pour un autre utilisateur', async () => {
    const list = await authed(accessToken).get('/api/v1/workout-sessions?limit=10').expect(200);
    const sessions = data<WorkoutSessionSummary[]>(list.body);
    expect(sessions.map((session) => session.id)).toContain(sessionId);
    const meta = (list.body as ApiSuccessEnvelope<unknown, CursorPaginationMeta>).meta;
    expect(typeof meta.hasMore).toBe('boolean');

    // L'autre utilisateur ne voit ni la liste ni le détail.
    const otherList = await authed(otherAccessToken)
      .get('/api/v1/workout-sessions?limit=10')
      .expect(200);
    expect(data<WorkoutSessionSummary[]>(otherList.body)).toHaveLength(0);
    await authed(otherAccessToken).get(`/api/v1/workout-sessions/${sessionId}`).expect(404);

    // Rejouer la création avec l'id d'autrui n'expose rien.
    await authed(otherAccessToken)
      .post('/api/v1/workout-sessions')
      .send({ id: sessionId, startedAt: '2026-08-07T10:00:00.000Z' })
      .expect(404);
  });

  it('abandonne une autre séance (rejouable)', async () => {
    const abandonedId = randomUUID();
    await authed(accessToken)
      .post('/api/v1/workout-sessions')
      .send({ id: abandonedId, startedAt: '2026-08-07T12:00:00.000Z' })
      .expect(201);

    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${abandonedId}/abandon`)
      .send({})
      .expect(200);
    const replay = await authed(accessToken)
      .post(`/api/v1/workout-sessions/${abandonedId}/abandon`)
      .send({})
      .expect(200);
    expect(data<WorkoutSessionDetail>(replay.body).status).toBe('ABANDONED');
  });
});
