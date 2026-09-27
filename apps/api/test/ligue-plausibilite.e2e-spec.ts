process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = process.env.CARLYS_E2E_LOG ?? 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  ACADEMY_LESSON_IDS,
  type ApiSuccessEnvelope,
  type AuthResult,
  type League,
  type WorkoutSessionDetail,
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
import { reinitialiserDebit } from './support/throttle';

/**
 * Ce qu'une séance ou une réponse de quiz verse à la ligue reste PLAUSIBLE,
 * les dates d'une séance restent dans le réel, et une semaine close ne
 * s'ouvre plus après coup. Mesuré avant : une séance vide valait 50 points,
 * une séance d'une minute déclarant 1 000 km en valait 11 540, vingt
 * réponses « justes » à des leçons inventées 200 de plus ; `endedAt` en 2099
 * rendait 500.
 */
describe('Ligue : bornes de plausibilité et dates de séance (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  const emails: string[] = [];

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const as = (token: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) => server().post(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${token}`),
  });

  const register = async (name: string): Promise<AuthResult> => {
    const email = `e2e-ligue-plaus-${name}-${randomUUID()}@carlys.test`;
    emails.push(email);
    return data<AuthResult>(
      (
        await server()
          .post('/api/v1/auth/register')
          .send({ email, password: 'MotDePasseSolide42', displayName: `Membre ${name}` })
          .expect(201)
      ).body,
    );
  };
  const rejoindre = async (token: string): Promise<void> => {
    await as(token).post('/api/v1/community/league/join').expect(201);
  };
  const score = async (token: string): Promise<number> =>
    data<League>((await as(token).get('/api/v1/community/league').expect(200)).body).score;

  /** Ouvre une séance, y pose les séries données, et renvoie son id. */
  const seance = async (
    token: string,
    options: {
      startedAt?: Date;
      sets?: Array<{ durationSeconds?: number; distanceMeters?: number }>;
    } = {},
  ): Promise<string> => {
    const id = randomUUID();
    const startedAt = options.startedAt ?? new Date(Date.now() - 60_000);
    await as(token)
      .post('/api/v1/workout-sessions')
      .send({ id, startedAt: startedAt.toISOString() })
      .expect(201);
    for (const [position, set] of (options.sets ?? []).entries()) {
      await as(token)
        .post(`/api/v1/workout-sessions/${id}/sets`)
        .send({
          id: randomUUID(),
          exerciseName: 'Course',
          position,
          completedAt: new Date().toISOString(),
          ...set,
        })
        .expect(201);
    }
    return id;
  };
  const clore = (token: string, id: string, body: Record<string, unknown> = {}) =>
    as(token).post(`/api/v1/workout-sessions/${id}/complete`).send(body);

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
  });

  beforeEach(reinitialiserDebit);

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('une séance VIDE ne rapporte rien ; une séance d’une minute « à 1 000 km » reste plausible', async () => {
    const u = await register('effort');
    await rejoindre(u.tokens.accessToken);

    await clore(u.tokens.accessToken, await seance(u.tokens.accessToken)).expect(200);
    expect(await score(u.tokens.accessToken)).toBe(0);

    const minute = await seance(u.tokens.accessToken, {
      sets: [{ distanceMeters: 1_000_000, durationSeconds: 86_400 }],
    });
    await clore(u.tokens.accessToken, minute).expect(200);
    // Avant : 11 540 points. Après : 50 (la séance) + 1 (60 s) + 12 (1,2 km),
    // à quelques secondes de créneau près.
    const apres = await score(u.tokens.accessToken);
    expect(apres).toBeGreaterThanOrEqual(50);
    expect(apres).toBeLessThan(100);
  });

  it('au-delà de 3 séances le même jour, une séance ne rapporte plus rien', async () => {
    const u = await register('boucle');
    await rejoindre(u.tokens.accessToken);
    for (let i = 0; i < 4; i += 1) {
      const id = await seance(u.tokens.accessToken, { sets: [{}] });
      await clore(u.tokens.accessToken, id).expect(200);
    }
    expect(await score(u.tokens.accessToken)).toBe(150);
  });

  it('quiz : une leçon inventée est refusée, et 3 bonnes réponses par jour comptent au plus', async () => {
    const u = await register('quiz');
    await rejoindre(u.tokens.accessToken);
    const aujourdHui = new Date().toISOString().slice(0, 10);

    await as(u.tokens.accessToken)
      .post('/api/v1/community/quiz-answers')
      .send({ lessonId: 'lecon-inventee-1', answeredOn: aujourdHui, correct: true })
      .expect(400);

    for (const lessonId of ACADEMY_LESSON_IDS.slice(0, 5)) {
      await as(u.tokens.accessToken)
        .post('/api/v1/community/quiz-answers')
        .send({ lessonId, answeredOn: aujourdHui, correct: true })
        .expect(204);
    }
    expect(await score(u.tokens.accessToken)).toBe(30);
    // Les cinq réponses sont gardées : la progression de l'Académie les relit.
    expect(await prisma.quizAnswer.count({ where: { userId: u.user.id } })).toBe(5);
  });

  it('dates : fin future refusée (400, plus de 500), fin antérieure ramenée au début, début ancien accepté', async () => {
    const u = await register('dates');
    const token = u.tokens.accessToken;

    // La seconde date est RELATIVE : au-delà du jour de tolérance d'horloge,
    // quelle que soit la date du jour. Une date fixe (« 2030 ») cesserait
    // d'être future — et le test de passer — sans qu'aucun code ait changé.
    const dansTroisJours = new Date(Date.now() + 3 * 86_400_000).toISOString();
    for (const endedAt of ['2099-06-15T12:00:00.000Z', dansTroisJours]) {
      const id = await seance(token);
      await clore(token, id, { endedAt }).expect(400);
    }

    const avant = await seance(token);
    const close = data<WorkoutSessionDetail>(
      (await clore(token, avant, { endedAt: '2021-01-01T00:00:00.000Z' }).expect(200)).body,
    );
    expect(close.endedAt).toBe(close.startedAt);
    expect(close.durationSeconds).toBe(0);

    // Un début ANCIEN, lui, passe : une horloge d'appareil remise à une date
    // d'usine ne doit pas rendre la séance insynchronisable (un 4xx est
    // définitif pour la file). Il ne rapporte rien pour autant : le crédit
    // est borné au créneau, et la ligue n'ouvre pas une semaine close (test
    // suivant).
    await as(token)
      .post('/api/v1/workout-sessions')
      .send({ id: randomUUID(), startedAt: '2002-03-04T10:00:00.000Z' })
      .expect(201);
  });

  it('une séance laissée ouverte plus de 24 h se clôt (durée ramenée au plafond), au lieu d’être perdue', async () => {
    const u = await register('longue');
    const id = await seance(u.tokens.accessToken, {
      startedAt: new Date(Date.now() - 25 * 3_600_000),
    });
    const close = data<WorkoutSessionDetail>(
      (await clore(u.tokens.accessToken, id, { durationSeconds: 25 * 3_600 }).expect(200)).body,
    );
    expect(close.status).toBe('COMPLETED');
    expect(close.durationSeconds).toBe(24 * 3_600);
  });

  it('une séance datée d’une semaine close depuis longtemps n’y ouvre AUCUNE ligne', async () => {
    const u = await register('ancienne');
    await rejoindre(u.tokens.accessToken);
    const id = await seance(u.tokens.accessToken, {
      startedAt: new Date('2021-03-01T10:00:00Z'),
      sets: [{}],
    });
    await clore(u.tokens.accessToken, id, { endedAt: '2021-03-01T11:00:00.000Z' }).expect(200);

    const lignes = await prisma.leagueMembership.findMany({ where: { userId: u.user.id } });
    expect(lignes.map((ligne) => ligne.periodKey).filter((cle) => cle.startsWith('2021'))).toEqual(
      [],
    );
  });

  it('un membre qui QUITTE la ligue disparaît du classement des autres', async () => {
    const temoin = await register('temoin');
    const partant = await register('partant');
    await rejoindre(temoin.tokens.accessToken);
    await rejoindre(partant.tokens.accessToken);
    // Le partant marque des points : sa ligne de la semaine existe.
    await clore(
      partant.tokens.accessToken,
      await seance(partant.tokens.accessToken, { sets: [{}] }),
    ).expect(200);

    const avant = data<League>(
      (await as(temoin.tokens.accessToken).get('/api/v1/community/league').expect(200)).body,
    );
    // Précondition : les deux sont dans le même groupe.
    expect(avant.standings.map((ligne) => ligne.userId)).toContain(partant.user.id);

    await as(partant.tokens.accessToken).delete('/api/v1/community/league/join').expect(200);

    const apres = data<League>(
      (await as(temoin.tokens.accessToken).get('/api/v1/community/league').expect(200)).body,
    );
    expect(apres.standings.map((ligne) => ligne.userId)).not.toContain(partant.user.id);
    // Sa ligne reste en base, et compte au règlement de la semaine.
    expect(
      await prisma.leagueMembership.count({ where: { userId: partant.user.id } }),
    ).toBeGreaterThan(0);
  });
});
