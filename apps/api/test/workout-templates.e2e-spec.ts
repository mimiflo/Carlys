process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type CursorPaginationMeta,
  type WorkoutTemplateDetail,
  type WorkoutTemplateSummary,
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

const EXERCISE_SLUG = 'e2e-templates-exercice';

/**
 * Modèles de séance : l'écriture est un PUT de remplacement complet, donc
 * naturellement idempotent. Chaque écriture est REJOUÉE pour le vérifier.
 */
describe('Modèles de séance (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let accessToken: string;
  let otherAccessToken: string;
  let exerciseId: string;
  let exerciseName: string;

  const userEmail = `e2e-modeles-${randomUUID()}@carlys.test`;
  const otherEmail = `e2e-modeles-autre-${randomUUID()}@carlys.test`;

  const templateId = randomUUID();
  const lineId = randomUUID();
  const warmupSetId = randomUUID();
  const workSetId = randomUUID();

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

  const body = () => ({
    name: 'Push — Force',
    notes: 'Focus haut du pectoral',
    estimatedDurationMinutes: 55,
    exercises: [
      {
        id: lineId,
        exerciseId,
        exerciseName: 'Nom que le catalogue doit écraser',
        notes: null,
        sets: [
          { id: warmupSetId, kind: 'WARMUP', targetReps: 12, targetWeightKg: 40, restSeconds: 60 },
          { id: workSetId, kind: 'NORMAL', targetReps: 8, targetWeightKg: 70, restSeconds: 120 },
        ],
      },
    ],
  });

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
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

    // Fixture dédiée : la suite ne dépend JAMAIS du seed (base CI vierge).
    const exercise = await ensureExerciseFixture(prisma, EXERCISE_SLUG);
    exerciseId = exercise.id;
    exerciseName = exercise.name;
  });

  afterAll(async () => {
    // Nettoyage strictement limité à cette suite (les e2e partagent la base).
    await prisma.user.deleteMany({ where: { email: { in: [userEmail, otherEmail] } } });
    await prisma.exercise.deleteMany({ where: { slug: EXERCISE_SLUG } });
    await prisma.$disconnect();
    await app.close();
  });

  const authed = (token: string) => ({
    put: (url: string) =>
      request(app.getHttpServer()).put(url).set('Authorization', `Bearer ${token}`),
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) =>
      request(app.getHttpServer()).delete(url).set('Authorization', `Bearer ${token}`),
  });

  it('crée un modèle (201) et le REJOUE à l’identique (200, même état)', async () => {
    const created = await authed(accessToken)
      .put(`/api/v1/workout-templates/${templateId}`)
      .send(body())
      .expect(201);
    const first = data<WorkoutTemplateDetail>(created.body);

    expect(first.id).toBe(templateId);
    expect(first.exercisesCount).toBe(1);
    expect(first.plannedSetsCount).toBe(2);
    expect(first.previewExerciseNames).toEqual([exerciseName]);
    // Le catalogue gagne sur le nom transmis par le client.
    expect(first.exercises[0]?.exerciseName).toBe(exerciseName);
    // Les positions ne sont pas transmises : elles viennent de l'ordre reçu.
    expect(first.exercises[0]?.position).toBe(0);
    expect(first.exercises[0]?.sets.map((set) => set.position)).toEqual([0, 1]);
    expect(first.exercises[0]?.sets[1]?.targetWeightKg).toBe(70);

    const replayed = await authed(accessToken)
      .put(`/api/v1/workout-templates/${templateId}`)
      .send(body())
      .expect(200);
    const second = data<WorkoutTemplateDetail>(replayed.body);

    expect(second.exercises).toEqual(first.exercises);
    expect(await prisma.workoutTemplateExercise.count({ where: { templateId } })).toBe(1);
    expect(await prisma.workoutTemplateSet.count({ where: { templateExerciseId: lineId } })).toBe(
      2,
    );
  });

  it('remplace intégralement le contenu : l’ancien est supprimé physiquement', async () => {
    const newLineId = randomUUID();
    const newSetId = randomUUID();

    const replaced = await authed(accessToken)
      .put(`/api/v1/workout-templates/${templateId}`)
      .send({
        name: 'Push — Volume',
        exercises: [
          {
            id: newLineId,
            exerciseName: 'Écarté poulie',
            sets: [{ id: newSetId, targetReps: 15 }],
          },
        ],
      })
      .expect(200);
    const detail = data<WorkoutTemplateDetail>(replaced.body);

    expect(detail.name).toBe('Push — Volume');
    expect(detail.notes).toBeNull();
    expect(detail.estimatedDurationMinutes).toBeNull();
    expect(detail.exercises).toHaveLength(1);
    expect(detail.exercises[0]?.exerciseId).toBeNull();
    expect(await prisma.workoutTemplateExercise.count({ where: { id: lineId } })).toBe(0);
    expect(await prisma.workoutTemplateSet.count({ where: { id: warmupSetId } })).toBe(0);

    // On restaure le modèle de référence pour la suite des tests.
    await authed(accessToken)
      .put(`/api/v1/workout-templates/${templateId}`)
      .send(body())
      .expect(200);
  });

  it('refuse un corps invalide sans jamais écrire', async () => {
    const invalid = [
      { ...body(), exercises: [] },
      { ...body(), name: '' },
      { ...body(), estimatedDurationMinutes: 5_000 },
      {
        ...body(),
        exercises: [{ id: randomUUID(), sets: [] }], // ni exerciseId ni exerciseName
      },
      {
        ...body(),
        exercises: [
          { id: randomUUID(), exerciseName: 'Squat', sets: [{ id: workSetId, targetReps: 2_000 }] },
        ],
      },
    ];

    for (const payload of invalid) {
      await authed(accessToken)
        .put(`/api/v1/workout-templates/${randomUUID()}`)
        .send(payload)
        .expect(400);
    }
    // Le modèle de référence n'a pas bougé.
    const detail = await authed(accessToken)
      .get(`/api/v1/workout-templates/${templateId}`)
      .expect(200);
    expect(data<WorkoutTemplateDetail>(detail.body).name).toBe('Push — Force');
  });

  it('refuse un identifiant dupliqué dans le corps (rejeu impossible)', async () => {
    const duplicated = randomUUID();
    await authed(accessToken)
      .put(`/api/v1/workout-templates/${randomUUID()}`)
      .send({
        name: 'Doublon',
        exercises: [
          {
            id: randomUUID(),
            exerciseName: 'Squat',
            sets: [{ id: duplicated }, { id: duplicated }],
          },
        ],
      })
      .expect(400);
  });

  it('isole strictement les utilisateurs : 404 en lecture, 409 en écriture', async () => {
    await authed(otherAccessToken).get(`/api/v1/workout-templates/${templateId}`).expect(404);

    const otherList = await authed(otherAccessToken)
      .get('/api/v1/workout-templates?limit=10')
      .expect(200);
    expect(data<WorkoutTemplateSummary[]>(otherList.body)).toHaveLength(0);

    // Écrire sur l'id d'autrui : conflit franc, jamais un écrasement.
    await authed(otherAccessToken)
      .put(`/api/v1/workout-templates/${templateId}`)
      .send({
        name: 'Vol de modèle',
        exercises: [{ id: randomUUID(), exerciseName: 'X', sets: [] }],
      })
      .expect(409);

    // Supprimer le modèle d'autrui ne le supprime pas.
    await authed(otherAccessToken).delete(`/api/v1/workout-templates/${templateId}`).expect(404);
    await authed(accessToken).get(`/api/v1/workout-templates/${templateId}`).expect(200);
  });

  it('liste les modèles paginés par curseur, du plus récemment retouché', async () => {
    const secondId = randomUUID();
    await authed(accessToken)
      .put(`/api/v1/workout-templates/${secondId}`)
      .send({
        name: 'Pull — Force',
        exercises: [{ id: randomUUID(), exerciseName: 'Rowing', sets: [{ id: randomUUID() }] }],
      })
      .expect(201);

    const firstPage = await authed(accessToken)
      .get('/api/v1/workout-templates?limit=1')
      .expect(200);
    const page = data<WorkoutTemplateSummary[]>(firstPage.body);
    const meta = (firstPage.body as ApiSuccessEnvelope<unknown, CursorPaginationMeta>).meta;

    expect(page).toHaveLength(1);
    expect(page[0]?.id).toBe(secondId); // updatedAt DESC
    expect(meta.hasMore).toBe(true);
    expect(meta.nextCursor).toBe(secondId);

    const secondPage = await authed(accessToken)
      .get(`/api/v1/workout-templates?limit=10&cursor=${meta.nextCursor ?? ''}`)
      .expect(200);
    expect(data<WorkoutTemplateSummary[]>(secondPage.body).map((item) => item.id)).toEqual([
      templateId,
    ]);

    await authed(accessToken).delete(`/api/v1/workout-templates/${secondId}`).expect(204);
  });

  it('supprime logiquement, de façon rejouable, et ne ressuscite pas par PUT', async () => {
    await authed(accessToken).delete(`/api/v1/workout-templates/${templateId}`).expect(204);
    // Rejeu d'une suppression déjà propagée : succès.
    await authed(accessToken).delete(`/api/v1/workout-templates/${templateId}`).expect(204);
    // Suppression d'un modèle jamais connu : succès aussi.
    await authed(accessToken).delete(`/api/v1/workout-templates/${randomUUID()}`).expect(204);

    await authed(accessToken).get(`/api/v1/workout-templates/${templateId}`).expect(404);
    await authed(accessToken)
      .put(`/api/v1/workout-templates/${templateId}`)
      .send(body())
      .expect(404);

    // Suppression LOGIQUE : la ligne survit, l'historique peut s'y référer.
    const stored = await prisma.workoutTemplate.findUnique({ where: { id: templateId } });
    expect(stored?.deletedAt).not.toBeNull();

    const list = await authed(accessToken).get('/api/v1/workout-templates?limit=10').expect(200);
    expect(data<WorkoutTemplateSummary[]>(list.body)).toHaveLength(0);
  });

  it('exige un jeton valide sur toutes les routes', async () => {
    await request(app.getHttpServer()).get('/api/v1/workout-templates').expect(401);
    await request(app.getHttpServer())
      .put(`/api/v1/workout-templates/${randomUUID()}`)
      .send(body())
      .expect(401);
    await request(app.getHttpServer())
      .delete(`/api/v1/workout-templates/${randomUUID()}`)
      .expect(401);
  });
});
