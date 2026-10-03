process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';
// Un worker et son modèle : le coach est configuré ; le modèle lui-même est
// remplacé par un faux (COACH_MODEL_PORT), rien ne part sur le réseau.
process.env.COACH_API_BASE_URL ??= 'http://127.0.0.1:1/v1';
process.env.COACH_MODEL ??= 'modele-factice-e2e';
process.env.COACH_ENABLED = 'true';
process.env.COACH_MESSAGES_PER_MINUTE = '120';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type CoachReply,
  type WorkoutTemplateDetail,
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
import {
  COACH_MODEL_PORT,
  type CoachModelPort,
  type CoachTurnInput,
} from '../src/modules/coach/domain/coach-model.port';
import { ExercisesService } from '../src/modules/exercises/application/exercises.service';
import { ensureExerciseFixture } from './support/exercise-fixture';

/**
 * Les ACTIONS du coach (ADR 0014), de bout en bout, contre un faux modèle
 * qui fait exactement ce qu'on reproche à Qwen3-4B : il lit ses outils,
 * puis répond EN TEXTE SEUL — jamais `propose_session`, jamais la création.
 * Le serveur doit quand même rendre la carte, puis la séance enregistrée.
 */
describe('Coach : proposer et créer une séance, garanti (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let accessToken: string;
  let userId: string;
  const email = `e2e-coach-actions-${randomUUID()}@carlys.test`;
  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

  /** Ce que le faux a reçu à chaque appel : ce que l'orchestration lui a imposé. */
  const calls: CoachTurnInput[] = [];
  const TEXT_ONLY = 'Pour travailler les pecs, tu peux commencer par des pompes, 3 séries de 10.';
  const fakeModel: CoachModelPort = {
    reply: (input) => {
      calls.push(input);
      input.onText?.(TEXT_ONLY);
      return Promise.resolve({
        text: TEXT_ONLY,
        proposal: null,
        usage: { inputTokens: 100, outputTokens: 30, cacheReadTokens: 0 },
        refused: false,
      });
    },
  };

  // Base CI vierge : des groupes et des exercices à soi, liés comme le seed.
  const slugs = ['e2e-actions-squat', 'e2e-actions-fentes', 'e2e-actions-pompes'];
  const createdGroups: string[] = [];

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(COACH_MODEL_PORT)
      .useValue(fakeModel)
      .compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const group = async (slug: string) => {
      const existing = await prisma.muscleGroup.findUnique({ where: { slug } });
      if (existing !== null) return existing;
      createdGroups.push(slug);
      return prisma.muscleGroup.create({ data: { slug, name: slug } });
    };
    const quadriceps = await group('quadriceps');
    const pectoraux = await group('pectoraux');
    const muscles = [quadriceps, quadriceps, pectoraux];
    for (const [i, slug] of slugs.entries()) {
      const muscle = muscles[i] ?? quadriceps;
      const exercise = await ensureExerciseFixture(prisma, slug);
      await prisma.exerciseMuscle.upsert({
        where: { exerciseId_muscleGroupId: { exerciseId: exercise.id, muscleGroupId: muscle.id } },
        create: { exerciseId: exercise.id, muscleGroupId: muscle.id, role: 'PRIMARY' },
        update: {},
      });
    }
    await app.get(ExercisesService).invalidateCache();

    const registered = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email, password: 'MotDePasseSolide!2026', displayName: 'Coach actions' })
      .expect(201);
    const auth = data<AuthResult>(registered.body);
    accessToken = auth.tokens.accessToken;
    userId = auth.user.id;
    await prisma.userEntitlement.create({
      data: { userId, entitlementKey: 'ai_coaching', isActive: true },
    });
    const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    await redis.del(`coach:quota:${userId}:${new Date().toISOString().slice(0, 10)}`);
    await redis.quit();
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email } });
    await prisma.exercise.deleteMany({ where: { slug: { in: slugs } } });
    await prisma.muscleGroup.deleteMany({ where: { slug: { in: createdGroups } } });
    await app.get(ExercisesService).invalidateCache();
    await prisma.$disconnect();
    await app.close();
  });

  const post = (url: string) =>
    request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${accessToken}`);
  const get = (url: string) =>
    request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${accessToken}`);

  const openThread = async () => {
    const id = randomUUID();
    await post('/api/v1/coach/conversations').send({ id }).expect(201);
    return id;
  };
  const say = async (conversationId: string, content: string, id = randomUUID()) =>
    data<CoachReply>(
      (
        await post(`/api/v1/coach/conversations/${conversationId}/messages`)
          .send({ id, content })
          .expect(201)
      ).body,
    ).assistantMessage;

  it('« Par où je commence ? » : le modèle répond en texte seul, la carte arrive quand même', async () => {
    const conversationId = await openThread();
    calls.length = 0;

    const reply = await say(conversationId, 'Par où je commence ?');

    // L'orchestration a lu ses données et exigé une composition…
    const asked = calls[0];
    expect(asked?.compose?.candidates.map((item) => item.id).length).toBeGreaterThanOrEqual(2);
    expect(asked?.prefetched?.map((read) => read.call.name)).toEqual(
      expect.arrayContaining(['get_recent_sessions', 'get_personal_records', 'search_exercises']),
    );
    // … et, le modèle n'ayant rien proposé, l'a composée : une VRAIE séance.
    expect(reply.proposal).not.toBeNull();
    const fixtures = await prisma.exercise.findMany({ where: { slug: { in: slugs } } });
    for (const item of reply.proposal?.items ?? []) {
      expect(fixtures.map((exercise) => exercise.id)).toContain(item.exerciseId);
    }
    // Jamais le « tu peux commencer par des pompes… » seul.
    expect(reply.content).not.toBe(TEXT_ONLY);
    // Gardée d'office dans « Mes séances », catégorie Coach.
    expect(reply.createdWorkout?.templateId).toBe(reply.proposal?.id);
    const kept = await prisma.workoutTemplate.findUnique({ where: { id: reply.proposal?.id } });
    expect(kept?.fromCoach).toBe(true);

    // Retouchée depuis l'appareil (PUT complet, sans origine) : elle reste
    // une séance du coach.
    const detail = data<WorkoutTemplateDetail>(
      (await get(`/api/v1/workout-templates/${reply.proposal?.id}`).expect(200)).body,
    );
    await request(app.getHttpServer())
      .put(`/api/v1/workout-templates/${detail.id}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: 'Ma séance retouchée',
        exercises: detail.exercises.map((exercise) => ({
          id: exercise.id,
          exerciseId: exercise.exerciseId,
          sets: exercise.sets.map((set) => ({
            id: set.id,
            kind: set.kind,
            targetReps: set.targetReps,
            restSeconds: set.restSeconds,
          })),
        })),
      })
      .expect(200);
    const edited = await prisma.workoutTemplate.findUnique({ where: { id: detail.id } });
    expect(edited).toMatchObject({ name: 'Ma séance retouchée', fromCoach: true });
  });

  it('« Ok crée-la » : la DERNIÈRE proposition, déjà gardée, confirmée sans le modèle, jamais en double', async () => {
    const conversationId = await openThread();
    const proposed = await say(conversationId, 'J’ai seulement 25 minutes aujourd’hui.');
    const proposalId = proposed.proposal?.id;
    expect(proposalId).toBeDefined();
    const before = await prisma.workoutTemplate.count({ where: { userId } });
    calls.length = 0;

    const messageId = randomUUID();
    const created = await say(conversationId, 'Ok crée-la.', messageId);

    expect(calls).toHaveLength(0);
    expect(created.createdWorkout).toEqual({
      templateId: proposalId,
      name: proposed.proposal?.name,
    });
    expect(created.content).toContain('C’est enregistré');
    // La preuve est la base, pas le texte : le modèle de séance existe.
    const template = data<WorkoutTemplateDetail>(
      (await get(`/api/v1/workout-templates/${proposalId}`).expect(200)).body,
    );
    expect(template.exercises.map((exercise) => exercise.exerciseId)).toEqual([
      ...new Set(proposed.proposal?.items.map((item) => item.exerciseId)),
    ]);

    // Un double appui, un renvoi : le même message rend la même réponse…
    const replayed = await say(conversationId, 'Ok crée-la.', messageId);
    expect(replayed.id).toBe(created.id);
    // … et le redemander ne crée pas de seconde séance : proposée, elle
    // était déjà gardée ; la créer ne fait que le confirmer.
    const again = await say(conversationId, 'Enregistre ça.');
    expect(again.createdWorkout?.templateId).toBe(proposalId);
    expect(await prisma.workoutTemplate.count({ where: { userId } })).toBe(before);
  });

  it('« Crée-moi une séance jambes » : composée PUIS enregistrée, la carte et la séance', async () => {
    const conversationId = await openThread();

    const reply = await say(conversationId, 'Crée-moi une séance jambes.');

    expect(reply.proposal).not.toBeNull();
    expect(reply.createdWorkout?.templateId).toBe(reply.proposal?.id);
    await get(`/api/v1/workout-templates/${reply.proposal?.id}`).expect(200);
  });

  it('« ça fait 5 fois que je te demande » : la séance demandée plus haut, créée', async () => {
    const conversationId = await openThread();
    // Le fil de la capture : une séance demandée, une réponse sans carte.
    const asked = await prisma.coachMessage.create({
      data: {
        id: randomUUID(),
        conversationId,
        role: 'USER',
        content: 'tu me conseilles, quoi en séance quad fessiers ?',
      },
    });
    await prisma.coachMessage.create({
      data: {
        id: randomUUID(),
        conversationId,
        role: 'ASSISTANT',
        content: 'Je te conseille le squat au poids du corps, puis le pont fessier.',
        createdAt: new Date(asked.createdAt.getTime() + 1000),
      },
    });
    calls.length = 0;

    const reply = await say(
      conversationId,
      'Ça me rend fou ton truc, ça fait 5 fois que je te demande de créer une séance.',
    );

    // Composée d'après la demande d'avant (quadriceps), et enregistrée.
    expect(calls[0]?.compose?.context.join(' ')).toContain('quad fessiers');
    expect(reply.proposal).not.toBeNull();
    expect(reply.createdWorkout?.templateId).toBe(reply.proposal?.id);
  });

  it('« Quelle est la différence entre squat et presse ? » : une réponse, AUCUNE séance', async () => {
    const conversationId = await openThread();
    calls.length = 0;

    const reply = await say(conversationId, 'Quelle est la différence entre squat et presse ?');

    expect(calls[0]?.compose).toBeUndefined();
    expect(reply.proposal).toBeNull();
    expect(reply.createdWorkout).toBeNull();
    expect(reply.content).toBe(TEXT_ONLY);
  });

  it('« Ok crée-la » sans séance en vue : une question précise, rien de créé', async () => {
    const conversationId = await openThread();
    const before = await prisma.workoutTemplate.count({ where: { userId } });

    const reply = await say(conversationId, 'Ok crée-la.');

    expect(reply.content).toMatch(/\?$/);
    expect(reply.createdWorkout).toBeNull();
    expect(await prisma.workoutTemplate.count({ where: { userId } })).toBe(before);
  });
});
