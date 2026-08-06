process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type CursorPaginationMeta,
  type ExerciseDetail,
  type ExerciseSummary,
  type MuscleGroup,
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
 * Catalogue d'exercices : données injectées directement en base (préfixe e2e-)
 * pour ne pas dépendre du seed. Redis peut être absent (cache dégradé).
 */
describe('Exercices (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let accessToken: string;
  const userEmail = `e2e-exercices-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const meta = (body: unknown): CursorPaginationMeta =>
    (body as ApiSuccessEnvelope<unknown, CursorPaginationMeta>).meta;

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });

    const chest = await prisma.muscleGroup.upsert({
      where: { slug: 'e2e-pectoraux' },
      update: {},
      create: { slug: 'e2e-pectoraux', name: 'E2E Pectoraux', sortOrder: 900 },
    });
    const back = await prisma.muscleGroup.upsert({
      where: { slug: 'e2e-dos' },
      update: {},
      create: { slug: 'e2e-dos', name: 'E2E Dos', sortOrder: 901 },
    });
    const barbell = await prisma.equipment.upsert({
      where: { slug: 'e2e-barre' },
      update: {},
      create: { slug: 'e2e-barre', name: 'E2E Barre' },
    });

    const exercises = [
      {
        slug: 'e2e-a-developpe',
        name: 'E2E Développé',
        group: chest.id,
        difficulty: 'INTERMEDIATE',
      },
      { slug: 'e2e-b-pompes', name: 'E2E Pompes', group: chest.id, difficulty: 'BEGINNER' },
      { slug: 'e2e-c-rowing', name: 'E2E Rowing', group: back.id, difficulty: 'BEGINNER' },
      { slug: 'e2e-d-tractions', name: 'E2E Tractions', group: back.id, difficulty: 'ADVANCED' },
    ] as const;
    for (const exercise of exercises) {
      await prisma.exercise.upsert({
        where: { slug: exercise.slug },
        update: {},
        create: {
          slug: exercise.slug,
          name: exercise.name,
          description: `Description ${exercise.name}`,
          instructions: ['Étape 1', 'Étape 2'],
          difficulty: exercise.difficulty,
          type: 'STRENGTH',
          tags: ['e2e'],
          muscles: { create: { muscleGroupId: exercise.group, role: 'PRIMARY' } },
          equipment: { create: { equipmentId: barbell.id } },
        },
      });
    }
    await prisma.exercise.upsert({
      where: { slug: 'e2e-z-brouillon' },
      update: {},
      create: {
        slug: 'e2e-z-brouillon',
        name: 'E2E Brouillon non publié',
        description: 'Ne doit jamais apparaître',
        instructions: [],
        difficulty: 'BEGINNER',
        type: 'STRENGTH',
        isPublished: false,
        tags: ['e2e'],
      },
    });

    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const registered = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email: userEmail,
        password: 'MotDePasseSolide42',
        displayName: 'E2E Exercices',
      })
      .expect(201);
    accessToken = data<AuthResult>(registered.body).tokens.accessToken;
  });

  afterAll(async () => {
    await prisma.exercise.deleteMany({ where: { slug: { startsWith: 'e2e-' } } });
    await prisma.muscleGroup.deleteMany({ where: { slug: { startsWith: 'e2e-' } } });
    await prisma.equipment.deleteMany({ where: { slug: { startsWith: 'e2e-' } } });
    // Nettoyage strictement limité à cette suite (les e2e partagent la base).
    await prisma.user.deleteMany({ where: { email: userEmail } });
    await prisma.$disconnect();
    await app.close();
  });

  const get = (url: string) =>
    request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${accessToken}`);

  it('exige une authentification', async () => {
    await request(app.getHttpServer()).get('/api/v1/exercises').expect(401);
  });

  it('liste le catalogue sans les exercices non publiés', async () => {
    const response = await get('/api/v1/exercises?search=E2E&limit=50').expect(200);
    const items = data<ExerciseSummary[]>(response.body);

    const slugs = items.map((item) => item.slug);
    expect(slugs).toEqual(
      expect.arrayContaining(['e2e-a-developpe', 'e2e-b-pompes', 'e2e-c-rowing']),
    );
    expect(slugs).not.toContain('e2e-z-brouillon');
  });

  it('filtre par groupe musculaire et par difficulté', async () => {
    const byGroup = await get('/api/v1/exercises?muscleGroup=e2e-dos&limit=50').expect(200);
    const groupSlugs = data<ExerciseSummary[]>(byGroup.body).map((item) => item.slug);
    expect(groupSlugs).toEqual(expect.arrayContaining(['e2e-c-rowing', 'e2e-d-tractions']));
    expect(groupSlugs).not.toContain('e2e-a-developpe');

    const byDifficulty = await get(
      '/api/v1/exercises?search=E2E&difficulty=ADVANCED&limit=50',
    ).expect(200);
    expect(data<ExerciseSummary[]>(byDifficulty.body).map((item) => item.slug)).toEqual([
      'e2e-d-tractions',
    ]);
  });

  it('pagine par curseur sans doublon ni trou', async () => {
    const first = await get('/api/v1/exercises?search=E2E&limit=2').expect(200);
    const firstItems = data<ExerciseSummary[]>(first.body);
    const firstMeta = meta(first.body);
    expect(firstItems).toHaveLength(2);
    expect(firstMeta.hasMore).toBe(true);
    expect(firstMeta.nextCursor).toBe(firstItems[1]?.id);

    const second = await get(
      `/api/v1/exercises?search=E2E&limit=2&cursor=${firstMeta.nextCursor ?? ''}`,
    ).expect(200);
    const secondItems = data<ExerciseSummary[]>(second.body);

    const firstIds = new Set(firstItems.map((item) => item.id));
    expect(secondItems.some((item) => firstIds.has(item.id))).toBe(false);
    expect(secondItems.length).toBeGreaterThan(0);
  });

  it('refuse un curseur mal formé', async () => {
    await get('/api/v1/exercises?cursor=pas-un-uuid').expect(400);
  });

  it('sert la fiche détaillée par slug puis par id', async () => {
    const bySlug = await get('/api/v1/exercises/e2e-a-developpe').expect(200);
    const detail = data<ExerciseDetail>(bySlug.body);
    expect(detail.name).toBe('E2E Développé');
    expect(detail.instructions).toHaveLength(2);
    expect(detail.muscles[0]?.role).toBe('PRIMARY');
    expect(detail.equipment.map((equipment) => equipment.slug)).toContain('e2e-barre');

    const byId = await get(`/api/v1/exercises/${detail.id}`).expect(200);
    expect(data<ExerciseDetail>(byId.body).slug).toBe('e2e-a-developpe');
  });

  it('404 pour un exercice inconnu ou non publié', async () => {
    await get('/api/v1/exercises/inexistant').expect(404);
    await get('/api/v1/exercises/e2e-z-brouillon').expect(404);
  });

  it('sert les référentiels (groupes musculaires ordonnés, équipements)', async () => {
    const groups = await get('/api/v1/muscle-groups').expect(200);
    const groupSlugs = data<MuscleGroup[]>(groups.body).map((group) => group.slug);
    expect(groupSlugs).toEqual(expect.arrayContaining(['e2e-pectoraux', 'e2e-dos']));

    const equipment = await get('/api/v1/equipment').expect(200);
    expect(data<MuscleGroup[]>(equipment.body).map((item) => item.slug)).toContain('e2e-barre');
  });
});
