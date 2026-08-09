process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  PROGRAM_FREE_LIMIT,
  type ApiSuccessEnvelope,
  type AuthResult,
  type ProgramDetail,
  type ProgramSummary,
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
 * Programmes multi-semaines : le plan dans le TEMPS.
 *
 * Mêmes garanties d'écriture que les modèles de séance — identifiants venus de
 * l'appareil, `PUT` de remplacement complet — donc rejouables sans doublon.
 */
describe('Programmes (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let token: string;
  let otherToken: string;
  let templateId: string;
  const email = `e2e-programs-${randomUUID()}@carlys.test`;
  const otherEmail = `e2e-programs-autre-${randomUUID()}@carlys.test`;
  const programId = randomUUID();

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const as = (bearer: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${bearer}`),
    put: (url: string) => server().put(url).set('Authorization', `Bearer ${bearer}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${bearer}`),
  });

  const dayOf = (week: number, day: number, extra: Record<string, unknown> = {}) => ({
    id: randomUUID(),
    weekNumber: week,
    dayOfWeek: day,
    ...extra,
  });

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const register = async (mail: string) =>
      data<AuthResult>(
        (
          await server()
            .post('/api/v1/auth/register')
            .send({ email: mail, password: 'MotDePasseSolide42', displayName: 'Membre E2E' })
            .expect(201)
        ).body,
      ).tokens.accessToken;
    token = await register(email);
    otherToken = await register(otherEmail);

    // Un modèle de séance à référencer : le programme dit QUAND, le modèle QUOI.
    templateId = randomUUID();
    await as(token)
      .put(`/api/v1/workout-templates/${templateId}`)
      .send({
        name: 'Push A',
        exercises: [
          { id: randomUUID(), exerciseName: 'Développé couché', sets: [{ id: randomUUID() }] },
        ],
      })
      .expect(201);
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: [email, otherEmail] } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('création : 201, jours ordonnés, lien vers le modèle conservé', async () => {
    const detail = data<ProgramDetail>(
      (
        await as(token)
          .put(`/api/v1/programs/${programId}`)
          .send({
            name: 'Prise de masse',
            weeksCount: 4,
            days: [
              dayOf(1, 3, { templateId, label: 'Push A' }),
              dayOf(1, 1, { templateId }),
              dayOf(1, 7, { isRest: true }),
            ],
          })
          .expect(201)
      ).body,
    );

    expect(detail.days).toHaveLength(3);
    expect(detail.days.map((day) => day.dayOfWeek)).toEqual([1, 3, 7]);
    expect(detail.days[0]?.templateId).toBe(templateId);
    expect(detail.days[2]).toMatchObject({ isRest: true, templateId: null, label: 'Repos' });
  });

  it('rejeu du même corps : 200 et état identique, sans doublon', async () => {
    const body = {
      name: 'Prise de masse',
      weeksCount: 4,
      days: [dayOf(1, 1, { templateId })],
    };

    const first = data<ProgramDetail>(
      (await as(token).put(`/api/v1/programs/${programId}`).send(body).expect(200)).body,
    );
    const second = data<ProgramDetail>(
      (await as(token).put(`/api/v1/programs/${programId}`).send(body).expect(200)).body,
    );

    expect(second.days).toHaveLength(1);
    expect(second.name).toBe(first.name);
  });

  it('un seul programme actif : activer le suivant désactive le précédent', async () => {
    await as(token)
      .put(`/api/v1/programs/${programId}`)
      .send({ name: 'Prise de masse', weeksCount: 4, isActive: true, days: [] })
      .expect(200);

    const secondId = randomUUID();
    await as(token)
      .put(`/api/v1/programs/${secondId}`)
      .send({ name: 'Sèche', weeksCount: 6, isActive: true, days: [] })
      .expect(201);

    const programs = data<ProgramSummary[]>(
      (await as(token).get('/api/v1/programs').expect(200)).body,
    );
    const active = programs.filter((entry) => entry.isActive);
    expect(active).toHaveLength(1);
    expect(active[0]?.id).toBe(secondId);

    await as(token).delete(`/api/v1/programs/${secondId}`).expect(204);
  });

  it('semaine hors du plan et case occupée deux fois → 400', async () => {
    await as(token)
      .put(`/api/v1/programs/${randomUUID()}`)
      .send({ name: 'Invalide', weeksCount: 2, days: [dayOf(5, 1)] })
      .expect(400);

    await as(token)
      .put(`/api/v1/programs/${randomUUID()}`)
      .send({ name: 'Invalide', weeksCount: 2, days: [dayOf(1, 2), dayOf(1, 2)] })
      .expect(400);
  });

  it('modèle d’un autre compte : le lien tombe, le plan reste', async () => {
    const foreign = randomUUID();
    await as(otherToken)
      .put(`/api/v1/workout-templates/${foreign}`)
      .send({
        name: 'Modèle voisin',
        exercises: [{ id: randomUUID(), exerciseName: 'Squat', sets: [{ id: randomUUID() }] }],
      })
      .expect(201);

    const detail = data<ProgramDetail>(
      (
        await as(token)
          .put(`/api/v1/programs/${randomUUID()}`)
          .send({
            name: 'Avec modèle voisin',
            weeksCount: 1,
            days: [dayOf(1, 2, { templateId: foreign, label: 'Jambes' })],
          })
          .expect(201)
      ).body,
    );

    expect(detail.days[0]?.templateId).toBeNull();
    expect(detail.days[0]?.label).toBe('Jambes');
  });

  it('cloisonnement : le programme d’autrui est un 404, jamais un 403', async () => {
    await as(otherToken).get(`/api/v1/programs/${programId}`).expect(404);
    await as(otherToken).delete(`/api/v1/programs/${programId}`).expect(404);
    await as(otherToken)
      .put(`/api/v1/programs/${programId}`)
      .send({ name: 'Vol', weeksCount: 1, days: [] })
      .expect(409);
  });

  it('plafond du plan gratuit à la création, jamais à la modification', async () => {
    // Le compte a déjà un programme ; on remplit jusqu'au plafond.
    const existing = data<ProgramSummary[]>(
      (await as(token).get('/api/v1/programs').expect(200)).body,
    );
    const created: string[] = [];
    for (let i = existing.length; i < PROGRAM_FREE_LIMIT; i++) {
      const id = randomUUID();
      created.push(id);
      await as(token)
        .put(`/api/v1/programs/${id}`)
        .send({ name: `Plan ${i}`, weeksCount: 1, days: [] })
        .expect(201);
    }

    await as(token)
      .put(`/api/v1/programs/${randomUUID()}`)
      .send({ name: 'De trop', weeksCount: 1, days: [] })
      .expect(403);

    // Modifier reste possible : c'est la CRÉATION qui est plafonnée.
    await as(token)
      .put(`/api/v1/programs/${programId}`)
      .send({ name: 'Prise de masse v2', weeksCount: 4, days: [] })
      .expect(200);

    for (const id of created) {
      await as(token).delete(`/api/v1/programs/${id}`).expect(204);
    }
  });

  it('suppression logique, rejouable, et le programme disparaît de la liste', async () => {
    await as(token).delete(`/api/v1/programs/${programId}`).expect(204);
    await as(token).delete(`/api/v1/programs/${programId}`).expect(204);
    await as(token).get(`/api/v1/programs/${programId}`).expect(404);

    const programs = data<ProgramSummary[]>(
      (await as(token).get('/api/v1/programs').expect(200)).body,
    );
    expect(programs.some((entry) => entry.id === programId)).toBe(false);

    // Un programme supprimé ne ressuscite pas par un PUT.
    await as(token)
      .put(`/api/v1/programs/${programId}`)
      .send({ name: 'Retour', weeksCount: 1, days: [] })
      .expect(404);
  });
});
