process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiErrorEnvelope,
  type ApiSuccessEnvelope,
  type AuthResult,
  type ProgramDetail,
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
 * Une case du programme HONORÉE par une séance terminée ne change plus de
 * jour : le calendrier dirait sinon qu'on s'est entraîné un autre jour que
 * celui où on l'a fait. Le mobile ne propose plus ce déplacement ; l'API le
 * refuse en défense (409, message écrit pour la personne).
 */
describe('Programme : une case faite reste à son jour (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let token: string;
  const email = `e2e-case-faite-${randomUUID()}@carlys.test`;
  const programId = randomUUID();
  const casePull = randomUUID();
  const caseCourse = randomUUID();

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const as = () => ({
    put: (url: string) =>
      request(app.getHttpServer()).put(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${token}`),
  });
  const ecrire = (days: Array<{ id: string; dayOfWeek: number }>, startsOn?: string) =>
    as()
      .put(`/api/v1/programs/${programId}`)
      .send({
        name: 'Semaine type',
        weeksCount: 1,
        ...(startsOn === undefined ? {} : { startsOn }),
        days: days.map((day) => ({ ...day, weekNumber: 1, label: 'Séance' })),
      });

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
    token = data<AuthResult>(
      (
        await request(app.getHttpServer())
          .post('/api/v1/auth/register')
          .send({ email, password: 'MotDePasseSolide42', displayName: 'Case' })
          .expect(201)
      ).body,
    ).tokens.accessToken;

    // Mercredi « Pull », jeudi « Course ».
    await ecrire([
      { id: casePull, dayOfWeek: 3 },
      { id: caseCourse, dayOfWeek: 4 },
    ]).expect(201);
    // Le Pull est FAIT : une séance terminée honore sa case.
    const sessionId = randomUUID();
    await as()
      .post('/api/v1/workout-sessions')
      .send({ id: sessionId, startedAt: new Date().toISOString(), programDayId: casePull })
      .expect(201);
    await as().post(`/api/v1/workout-sessions/${sessionId}/complete`).expect(200);
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email } });
    await prisma.$disconnect();
    await app.close();
  });

  it('échanger la case faite avec une autre : 409, message pour la personne, rien d’écrit', async () => {
    const refus = await ecrire([
      { id: casePull, dayOfWeek: 4 },
      { id: caseCourse, dayOfWeek: 3 },
    ]).expect(409);
    const erreur = (refus.body as ApiErrorEnvelope).error;
    expect(erreur.code).toBe('CONFLICT');
    expect(erreur.message).toContain('déjà faite');

    const enBase = await prisma.programDay.findUniqueOrThrow({ where: { id: casePull } });
    expect(enBase.dayOfWeek).toBe(3);
  });

  it('déplacer une case NON faite, la faite restant en place : accepté', async () => {
    const programme = data<ProgramDetail>(
      (
        await ecrire([
          { id: casePull, dayOfWeek: 3 },
          { id: caseCourse, dayOfWeek: 6 },
        ]).expect(200)
      ).body,
    );
    expect(programme.days.map((day) => day.dayOfWeek)).toEqual([3, 6]);
  });

  describe('le premier jour déplace aussi la case faite', () => {
    const cases = () => [
      { id: casePull, dayOfWeek: 3 },
      { id: caseCourse, dayOfWeek: 6 },
    ];
    const premierJourEnBase = async () =>
      (await prisma.program.findUniqueOrThrow({ where: { id: programId } })).startsOn
        ?.toISOString()
        .slice(0, 10);

    it('donner sa première date au programme : aucun jour n’était revendiqué, accepté', async () => {
      // Départ le jeudi 24/09 : le Pull (mercredi) tombe le 23/09.
      await ecrire(cases(), '2026-09-24').expect(200);
      expect(await premierJourEnBase()).toBe('2026-09-24');
    });

    it('décaler le premier jour d’une semaine, cases inchangées : 409, rien d’écrit', async () => {
      // Avant correctif : 200, et le Pull fait le 23/09 passait au 16/09.
      const refus = await ecrire(cases(), '2026-09-17').expect(409);
      const erreur = (refus.body as ApiErrorEnvelope).error;
      expect(erreur.code).toBe('CONFLICT');
      expect(erreur.message).toContain('même semaine');
      expect(await premierJourEnBase()).toBe('2026-09-24');
    });

    it('reprendre le premier jour dans la même semaine : même lundi, accepté', async () => {
      await ecrire(cases(), '2026-09-21').expect(200);
      expect(await premierJourEnBase()).toBe('2026-09-21');
    });
  });
});
