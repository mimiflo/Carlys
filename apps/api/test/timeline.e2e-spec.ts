process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = process.env.CARLYS_E2E_LOG ?? 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type ProgressTimeline,
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
 * LA FRISE : quatre sources fusionnées, une page, un curseur.
 *
 * Ce qui se vérifie ici, et qui a décidé la conception : le curseur porte le
 * COUPLE (date, id) parce qu'un flux fusionné a des ex æquo ; les leçons se
 * groupent par jour APRÈS dédoublonnage ; un record battu puis rebattu
 * laisse DEUX lignes, là où `PersonalRecord` n'en garde qu'une ; et une
 * charge corrigée vers le bas fait disparaître le franchissement qu'elle
 * avait inventé.
 */
describe('Frise de progression (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let token: string;
  let userId: string;
  let exerciseId: string;
  const email = `e2e-timeline-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const as = (bearer: string) => ({
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${bearer}`),
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${bearer}`),
    patch: (url: string) =>
      request(app.getHttpServer()).patch(url).set('Authorization', `Bearer ${bearer}`),
  });

  const jours = (n: number) => new Date(Date.now() - n * 86_400_000).toISOString();

  /** Une séance d'une série chargée, close. Rend l'identifiant de la série. */
  const seance = async (joursAvant: number, weightKg: number): Promise<string> => {
    const sessionId = randomUUID();
    const setId = randomUUID();
    await as(token)
      .post('/api/v1/workout-sessions')
      .send({ id: sessionId, startedAt: jours(joursAvant) })
      .expect(201);
    await as(token)
      .post(`/api/v1/workout-sessions/${sessionId}/sets`)
      .send({
        id: setId,
        exerciseId,
        position: 0,
        reps: 5,
        weightKg,
        completedAt: jours(joursAvant),
      })
      .expect(201);
    await as(token).post(`/api/v1/workout-sessions/${sessionId}/complete`).send({}).expect(200);
    return setId;
  };

  const frise = async (query = ''): Promise<ProgressTimeline> =>
    data<ProgressTimeline>(
      (await as(token).get(`/api/v1/progress/timeline${query}`).expect(200)).body,
    );

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const inscrite = data<AuthResult>(
      (
        await request(app.getHttpServer())
          .post('/api/v1/auth/register')
          .send({ email, password: 'MotDePasseSolide42', displayName: 'Frise' })
          .expect(201)
      ).body,
    );
    token = inscrite.tokens.accessToken;
    userId = inscrite.user.id;

    const exercise = await ensureExerciseFixture(prisma, 'e2e-timeline-exercice');
    exerciseId = exercise.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email } });
    await prisma.exercise.deleteMany({ where: { slug: 'e2e-timeline-exercice' } });
    await prisma.$disconnect();
    await app.close();
  });

  it('un compte neuf a une frise VIDE, pas une erreur', async () => {
    const vide = await frise();
    expect(vide.items).toEqual([]);
    expect(vide.hasMore).toBe(false);
    expect(vide.nextCursor).toBeNull();
  });

  it('fusionne les sources, les plus récentes d’abord', async () => {
    await seance(30, 80);
    await seance(20, 85);
    await as(token)
      .post('/api/v1/body-metrics')
      .send({
        id: randomUUID(),
        metricType: 'WEIGHT_KG',
        value: 78.4,
        measuredAt: jours(10),
      })
      .expect(201);

    const page = await frise();
    const kinds = page.items.map((item) => item.kind);

    expect(kinds).toContain('SESSION');
    expect(kinds).toContain('MEASURE');
    expect(kinds).toContain('RECORD');
    // Du plus récent au plus ancien, sans exception : c'est l'ordre d'une
    // frise, et c'est celui que le curseur suppose.
    const dates = page.items.map((item) => Date.parse(item.occurredAt));
    expect([...dates].sort((a, b) => b - a)).toEqual(dates);
  });

  it('garde les DEUX franchissements d’un record rebattu', async () => {
    const records = (await frise('?kinds=RECORD')).items;
    const charges = records
      .map((item) => item.payload)
      .filter((payload) => payload['recordType'] === 'MAX_WEIGHT')
      .map((payload) => payload['value']);

    // 80 puis 85. `PersonalRecord` n'aurait gardé que le 85 : son unicité
    // `(userId, exerciseName, recordType)` en fait un mur de trophées, pas
    // une chronologie.
    expect(charges).toEqual([85, 80]);
    const stockes = await prisma.personalRecord.count({
      where: { userId, recordType: 'MAX_WEIGHT' },
    });
    expect(stockes).toBe(1);
  });

  it('une charge corrigée vers le bas EFFACE le franchissement qu’elle avait inventé', async () => {
    const setId = await seance(5, 300);
    expect((await frise('?kinds=RECORD')).items.some((item) => item.payload['value'] === 300)).toBe(
      true,
    );

    // La faute de frappe classique : 300 au lieu de 30.
    await as(token).patch(`/api/v1/workout-sets/${setId}`).send({ weightKg: 30 }).expect(200);

    const apres = (await frise('?kinds=RECORD')).items;
    expect(apres.some((item) => item.payload['value'] === 300)).toBe(false);
    // Et les vrais franchissements survivent à la correction.
    expect(apres.some((item) => item.payload['value'] === 85)).toBe(true);
  });

  it('groupe les leçons par JOUR, après dédoublonnage par leçon', async () => {
    const jour = new Date().toISOString().slice(0, 10);
    for (const lessonId of ['lecon-a', 'lecon-b', 'lecon-c']) {
      await as(token)
        .post('/api/v1/community/quiz-answers')
        .send({ lessonId, answeredOn: jour, correct: true, choiceIndex: 0 })
        .expect(204);
    }

    const lecons = (await frise('?kinds=LESSON')).items;
    // UNE ligne pour le jour, pas trois : cinquante-huit lignes de bruit
    // noieraient la frise.
    expect(lecons).toHaveLength(1);
    expect(lecons[0]?.payload['lessons']).toBe(3);
  });

  it('pagine par un curseur qui ne saute ni ne rejoue', async () => {
    const tout = (await frise('?limit=50')).items;
    expect(tout.length).toBeGreaterThan(3);

    const vus: string[] = [];
    let cursor: string | null = null;
    let tours = 0;
    do {
      const page: ProgressTimeline = await frise(
        `?limit=2${cursor === null ? '' : `&cursor=${encodeURIComponent(cursor)}`}`,
      );
      vus.push(...page.items.map((item) => item.id));
      cursor = page.nextCursor;
      tours += 1;
    } while (cursor !== null && tours < 50);

    // Exactement la même liste, dans le même ordre, sans doublon.
    expect(vus).toEqual(tout.map((item) => item.id));
    expect(new Set(vus).size).toBe(vus.length);
  });

  it('un curseur illisible repart du début, il ne fait pas échouer l’écran', async () => {
    const page = await frise('?limit=3&cursor=pas-un-curseur');
    expect(page.items).toHaveLength(3);
  });

  it('importe le journal local, et la plus ANCIENNE date gagne', async () => {
    const recent = jours(3);
    const ancien = jours(40);

    await as(token)
      .post('/api/v1/progress/milestones')
      .send({ milestones: [{ kind: 'REWARD', key: 'constance-4', occurredAt: recent }] })
      .expect(204);
    // Un second appareil, qui avait regardé plus tôt : c'est SA date qui
    // fait foi — le journal date du jour où l'application a regardé, pas du
    // jour du fait.
    await as(token)
      .post('/api/v1/progress/milestones')
      .send({ milestones: [{ kind: 'REWARD', key: 'constance-4', occurredAt: ancien }] })
      .expect(204);
    // Et le rejeu de la date récente ne la remonte pas.
    await as(token)
      .post('/api/v1/progress/milestones')
      .send({ milestones: [{ kind: 'REWARD', key: 'constance-4', occurredAt: recent }] })
      .expect(204);

    const recompenses = (await frise('?kinds=REWARD')).items;
    expect(recompenses).toHaveLength(1);
    expect(recompenses[0]?.occurredAt.slice(0, 10)).toBe(ancien.slice(0, 10));
  });

  it('refuse un franchissement daté du futur, et un RECORD importé', async () => {
    // Au-delà de la tolérance d'horloge partagée (24 h) : une horloge de
    // téléphone en avance de quelques minutes reste légitime, une date de
    // la semaine prochaine ne l'est pas.
    const plusTard = new Date(Date.now() + 10 * 86_400_000).toISOString();
    await as(token)
      .post('/api/v1/progress/milestones')
      .send({ milestones: [{ kind: 'REWARD', key: 'constance-8', occurredAt: plusTard }] })
      .expect(400);

    // Les records se DÉRIVENT des séries : les accepter d'un client
    // laisserait inventer un franchissement qu'aucune série ne justifie.
    await as(token)
      .post('/api/v1/progress/milestones')
      .send({
        milestones: [{ kind: 'RECORD', key: 'record:Triche|MAX_WEIGHT|500', occurredAt: jours(1) }],
      })
      .expect(400);
  });

  it('la frise d’autrui reste invisible', async () => {
    const autre = data<AuthResult>(
      (
        await request(app.getHttpServer())
          .post('/api/v1/auth/register')
          .send({
            email: `e2e-timeline-autre-${randomUUID()}@carlys.test`,
            password: 'MotDePasseSolide42',
            displayName: 'Autre',
          })
          .expect(201)
      ).body,
    );
    const vue = data<ProgressTimeline>(
      (await as(autre.tokens.accessToken).get('/api/v1/progress/timeline').expect(200)).body,
    );
    expect(vue.items).toEqual([]);
    await prisma.user.deleteMany({ where: { id: autre.user.id } });
  });
});
