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
    put: (url: string) =>
      request(app.getHttpServer()).put(url).set('Authorization', `Bearer ${token}`),
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

  it('lance un modèle : templateId retenu, dernier lancement daté, cible persistée', async () => {
    const templateId = randomUUID();
    const exercise = await ensureExerciseFixture(prisma, 'e2e-workouts-exercice');
    await authed(accessToken)
      .put(`/api/v1/workout-templates/${templateId}`)
      .send({
        name: 'Push — Force',
        exercises: [
          {
            id: randomUUID(),
            exerciseId: exercise.id,
            sets: [{ id: randomUUID(), targetReps: 8 }],
          },
        ],
      })
      .expect(201);

    const fromTemplateId = randomUUID();
    const startedAt = '2026-08-07T14:00:00.000Z';
    const created = await authed(accessToken)
      .post('/api/v1/workout-sessions')
      .send({ id: fromTemplateId, startedAt, templateId, templateName: 'Nom client périmé' })
      .expect(201);
    const session = data<WorkoutSessionDetail>(created.body);

    // Le nom SERVEUR gagne : la provenance est décidée côté serveur.
    expect(session.templateId).toBe(templateId);
    expect(session.templateName).toBe('Push — Force');
    const template = await prisma.workoutTemplate.findUnique({ where: { id: templateId } });
    expect(template?.lastUsedAt?.toISOString()).toBe(startedAt);

    // Déviation assumée : 7 reps faites pour 8 prévues — enregistré, jamais refusé.
    const deviatedSetId = randomUUID();
    const set = await authed(accessToken)
      .post(`/api/v1/workout-sessions/${fromTemplateId}/sets`)
      .send({
        id: deviatedSetId,
        exerciseId: exercise.id,
        position: 0,
        reps: 7,
        weightKg: 60,
        plannedReps: 8,
        plannedWeightKg: 60,
        completedAt: '2026-08-07T14:10:00.000Z',
      })
      .expect(201);
    expect(data<WorkoutSet>(set.body).reps).toBe(7);
    expect(data<WorkoutSet>(set.body).plannedReps).toBe(8);
    expect(data<WorkoutSet>(set.body).plannedWeightKg).toBe(60);

    // Corriger le FAIT ne réécrit jamais la cible affichée à la validation.
    await authed(accessToken)
      .patch(`/api/v1/workout-sets/${deviatedSetId}`)
      .send({ reps: 9, plannedReps: 3 })
      .expect(400);
    const corrected = await authed(accessToken)
      .patch(`/api/v1/workout-sets/${deviatedSetId}`)
      .send({ reps: 9 })
      .expect(200);
    expect(data<WorkoutSet>(corrected.body).reps).toBe(9);
    expect(data<WorkoutSet>(corrected.body).plannedReps).toBe(8);
  });

  it('le plan part avec la séance et se relit à l’identique — reprise multi-appareil', async () => {
    const exercise = await ensureExerciseFixture(prisma, 'e2e-workouts-plan');
    const plannedSessionId = randomUUID();
    const [first, second, third] = [randomUUID(), randomUUID(), randomUUID()];
    const body = {
      id: plannedSessionId,
      startedAt: '2026-08-07T16:00:00.000Z',
      templateName: 'Push — Force',
      plan: [
        {
          id: first,
          exercisePosition: 0,
          exerciseId: exercise.id,
          exerciseName: 'Nom client périmé',
          setPosition: 0,
          targetReps: 8,
          targetWeightKg: 60,
          restSeconds: 90,
        },
        {
          id: second,
          exercisePosition: 0,
          exerciseId: exercise.id,
          exerciseName: 'Nom client périmé',
          setPosition: 1,
          targetReps: 8,
          targetWeightKg: 60,
          restSeconds: 90,
        },
        {
          id: third,
          exercisePosition: 1,
          exerciseName: 'Gainage libre',
          setPosition: 0,
          targetReps: 3,
        },
      ],
    };

    const created = await authed(accessToken)
      .post('/api/v1/workout-sessions')
      .send(body)
      .expect(201);
    expect(data<WorkoutSessionDetail>(created.body).plan).toHaveLength(3);

    // REJEU de la création : le plan ne doit surtout pas se dupliquer.
    await authed(accessToken).post('/api/v1/workout-sessions').send(body).expect(201);
    expect(
      await prisma.workoutSessionPlanItem.count({ where: { sessionId: plannedSessionId } }),
    ).toBe(3);

    // Première série faite : elle honore la première prévision.
    const doneSetId = randomUUID();
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${plannedSessionId}/sets`)
      .send({
        id: doneSetId,
        exerciseId: exercise.id,
        position: 0,
        reps: 8,
        weightKg: 60,
        plannedReps: 8,
        plannedWeightKg: 60,
        planItemId: first,
        completedAt: '2026-08-07T16:05:00.000Z',
      })
      .expect(201);

    // Deuxième prévision explicitement passée (rejouable).
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${plannedSessionId}/plan/skip`)
      .send({ planItemIds: [second] })
      .expect(200);
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${plannedSessionId}/plan/skip`)
      .send({ planItemIds: [second] })
      .expect(200);

    // Passer une prévision DÉJÀ FAITE ne l'écrase pas : un fait reste un fait.
    await authed(accessToken)
      .post(`/api/v1/workout-sessions/${plannedSessionId}/plan/skip`)
      .send({ planItemIds: [first] })
      .expect(200);

    // Ce que verrait un second appareil : il relit simplement le détail.
    const resumed = await authed(accessToken)
      .get(`/api/v1/workout-sessions/${plannedSessionId}`)
      .expect(200);
    const plan = data<WorkoutSessionDetail>(resumed.body).plan;

    expect(plan).toHaveLength(3);
    expect(plan[0]).toMatchObject({
      id: first,
      // Nom du CATALOGUE, pas celui transmis par le client.
      exerciseName: exercise.name,
      targetReps: 8,
      targetWeightKg: 60,
      doneSetId,
      skipped: false,
    });
    expect(plan[1]).toMatchObject({ id: second, skipped: true, doneSetId: null });
    // Exercice hors catalogue : conservé tel quel, sans clé étrangère.
    expect(plan[2]).toMatchObject({ id: third, exerciseId: null, exerciseName: 'Gainage libre' });

    // Le plan d'autrui reste invisible.
    await authed(otherAccessToken)
      .post(`/api/v1/workout-sessions/${plannedSessionId}/plan/skip`)
      .send({ planItemIds: [third] })
      .expect(404);
  });

  it('une séance dont le modèle est inconnu arrive QUAND MÊME, nom client conservé', async () => {
    const orphanId = randomUUID();
    const created = await authed(accessToken)
      .post('/api/v1/workout-sessions')
      .send({
        id: orphanId,
        startedAt: '2026-08-07T15:00:00.000Z',
        templateId: randomUUID(), // jamais synchronisé, ou refusé définitivement
        templateName: '  Push — Force  ',
      })
      .expect(201);
    const session = data<WorkoutSessionDetail>(created.body);

    expect(session.templateId).toBeNull();
    expect(session.templateName).toBe('Push — Force');
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
