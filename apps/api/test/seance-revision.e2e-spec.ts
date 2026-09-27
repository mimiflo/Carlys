process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type WorkoutSessionDetail,
  type WorkoutSessionSummary,
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
 * LA RÉVISION D'UNE SÉANCE : ce qui permet au téléphone de ne retélécharger
 * que ce qui a changé.
 *
 * Le rapatriement relisait les soixante dernières séances à chaque
 * lancement à froid, même identiques. Il lui faut une valeur qui change dès
 * que la séance, l'une de ses séries (suppression comprise) ou son plan
 * change, et JAMAIS sinon : un faux « changé » coûte un téléchargement, un
 * faux « inchangé » cache pour toujours une correction faite ailleurs.
 *
 * Chaque épreuve compare la liste (ce que le téléphone lit d'abord) et le
 * détail (ce qu'il enregistre ensuite) : elles doivent dire la même chose.
 */
describe('Révision d’une séance (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let token: string;
  const email = `e2e-revision-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const as = () => ({
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${token}`),
    patch: (url: string) =>
      request(app.getHttpServer()).patch(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) =>
      request(app.getHttpServer()).delete(url).set('Authorization', `Bearer ${token}`),
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
          .send({ email, password: 'MotDePasseSolide42', displayName: 'E2E' })
          .expect(201)
      ).body,
    ).tokens.accessToken;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email } });
    await prisma.$disconnect();
    await app.close();
  });

  /** La révision servie par le détail, après avoir vérifié que la liste dit la même. */
  const revisionOf = async (sessionId: string): Promise<number> => {
    const detail = data<WorkoutSessionDetail>(
      (await as().get(`/api/v1/workout-sessions/${sessionId}`).expect(200)).body,
    );
    const listed = data<WorkoutSessionSummary[]>(
      (await as().get('/api/v1/workout-sessions?limit=50').expect(200)).body,
    ).find((session) => session.id === sessionId);
    expect(Number.isInteger(detail.revision)).toBe(true);
    expect(listed?.revision).toBe(detail.revision);
    return detail.revision;
  };

  const changes = async (sessionId: string, write: () => Promise<unknown>): Promise<void> => {
    const before = await revisionOf(sessionId);
    await write();
    expect(await revisionOf(sessionId)).not.toBe(before);
  };

  const keeps = async (sessionId: string, write: () => Promise<unknown>): Promise<void> => {
    const before = await revisionOf(sessionId);
    await write();
    expect(await revisionOf(sessionId)).toBe(before);
  };

  const newSession = async (planItemIds: string[] = []): Promise<string> => {
    const id = randomUUID();
    await as()
      .post('/api/v1/workout-sessions')
      .send({
        id,
        startedAt: new Date().toISOString(),
        plan: planItemIds.map((planItemId, setPosition) => ({
          id: planItemId,
          exercisePosition: 0,
          exerciseName: 'Pompes',
          setPosition,
          targetReps: 10,
        })),
      })
      .expect(201);
    return id;
  };

  const setBody = (id: string, extra: Record<string, unknown> = {}) => ({
    id,
    exerciseName: 'Pompes',
    position: 0,
    reps: 10,
    completedAt: new Date().toISOString(),
    ...extra,
  });

  it('une relecture, ou le rejeu d’une création, ne change rien', async () => {
    const sessionId = await newSession([randomUUID()]);
    await keeps(sessionId, () => as().get(`/api/v1/workout-sessions/${sessionId}`).expect(200));
    await keeps(sessionId, () =>
      as()
        .post('/api/v1/workout-sessions')
        .send({ id: sessionId, startedAt: new Date().toISOString() })
        .expect(201),
    );
  });

  it('la séance elle-même : renommer, noter, clôturer', async () => {
    const sessionId = await newSession();
    await changes(sessionId, () =>
      as().patch(`/api/v1/workout-sessions/${sessionId}`).send({ name: 'Push A' }).expect(200),
    );
    await changes(sessionId, () =>
      as()
        .patch(`/api/v1/workout-sessions/${sessionId}`)
        .send({ notes: 'Bonne forme' })
        .expect(200),
    );
    await changes(sessionId, () =>
      as().post(`/api/v1/workout-sessions/${sessionId}/complete`).send({}).expect(200),
    );
    // Le rejeu d'une clôture n'est pas une modification.
    await keeps(sessionId, () =>
      as().post(`/api/v1/workout-sessions/${sessionId}/complete`).send({}).expect(200),
    );
  });

  it('l’abandon aussi', async () => {
    const sessionId = await newSession();
    await changes(sessionId, () =>
      as().post(`/api/v1/workout-sessions/${sessionId}/abandon`).send({}).expect(200),
    );
    await keeps(sessionId, () =>
      as().post(`/api/v1/workout-sessions/${sessionId}/abandon`).send({}).expect(200),
    );
  });

  it('une série : ajoutée, corrigée, supprimée — et ses rejeux ne comptent pas', async () => {
    const sessionId = await newSession();
    const setId = randomUUID();
    const add = () =>
      as().post(`/api/v1/workout-sessions/${sessionId}/sets`).send(setBody(setId)).expect(201);

    await changes(sessionId, add);
    await keeps(sessionId, add);
    await changes(sessionId, () =>
      as().patch(`/api/v1/workout-sets/${setId}`).send({ reps: 12 }).expect(200),
    );
    // La correction d'une série au poids du corps ne change ni le volume ni
    // le nombre de séries : seule la révision la signale.
    await changes(sessionId, () =>
      as().patch(`/api/v1/workout-sets/${setId}`).send({ rpe: 8 }).expect(200),
    );
    // Une série SUPPRIMÉE n'est plus servie : sans révision, le téléphone ne
    // saurait jamais qu'elle a disparu.
    await changes(sessionId, () => as().delete(`/api/v1/workout-sets/${setId}`).expect(204));
    await keeps(sessionId, () => as().delete(`/api/v1/workout-sets/${setId}`).expect(204));
  });

  it('corriger la série d’une séance TERMINÉE la signale aussi', async () => {
    const sessionId = await newSession();
    const setId = randomUUID();
    await as().post(`/api/v1/workout-sessions/${sessionId}/sets`).send(setBody(setId)).expect(201);
    await as().post(`/api/v1/workout-sessions/${sessionId}/complete`).send({}).expect(200);
    await changes(sessionId, () =>
      as().patch(`/api/v1/workout-sets/${setId}`).send({ reps: 11 }).expect(200),
    );
  });

  it('le plan : prévision honorée, prévision passée — et leurs rejeux ne comptent pas', async () => {
    const [honoree, passee] = [randomUUID(), randomUUID()];
    const sessionId = await newSession([honoree, passee]);
    const setId = randomUUID();

    // La série arrive d'abord SANS son appariement (envoi interrompu entre
    // les deux écritures), puis son rejeu apparie : seul le plan change.
    await as().post(`/api/v1/workout-sessions/${sessionId}/sets`).send(setBody(setId)).expect(201);
    const linkReplay = () =>
      as()
        .post(`/api/v1/workout-sessions/${sessionId}/sets`)
        .send(setBody(setId, { planItemId: honoree }))
        .expect(201);
    await changes(sessionId, linkReplay);
    await keeps(sessionId, linkReplay);

    const skip = () =>
      as()
        .post(`/api/v1/workout-sessions/${sessionId}/plan/skip`)
        .send({ planItemIds: [passee] })
        .expect(200);
    await changes(sessionId, skip);
    await keeps(sessionId, skip);

    // Supprimer la série rend sa prévision : le plan change avec elle.
    await changes(sessionId, () => as().delete(`/api/v1/workout-sets/${setId}`).expect(204));
    const detail = data<WorkoutSessionDetail>(
      (await as().get(`/api/v1/workout-sessions/${sessionId}`).expect(200)).body,
    );
    expect(detail.plan.find((item) => item.id === honoree)?.doneSetId).toBeNull();
  });

  it('une écriture qui ignore la révision la fait monter quand même (retour arrière du déploiement)', async () => {
    // Le retour arrière remet le CODE d'avant, jamais le SCHÉMA : ce code
    // écrit séries, plan et séance sans connaître la révision. C'est la base
    // qui la tient, quel que soit le code qui écrit.
    const planItemId = randomUUID();
    const sessionId = await newSession([planItemId]);
    const setId = randomUUID();
    await changes(sessionId, () =>
      prisma.workoutSet.create({
        data: {
          id: setId,
          sessionId,
          exerciseName: 'Pompes',
          position: 0,
          reps: 10,
          completedAt: new Date(),
        },
      }),
    );
    await changes(sessionId, () =>
      prisma.workoutSet.update({ where: { id: setId }, data: { reps: 12 } }),
    );
    await changes(sessionId, () =>
      prisma.workoutSessionPlanItem.updateMany({
        where: { id: planItemId, sessionId },
        data: { doneSetId: setId },
      }),
    );
    await changes(sessionId, () =>
      prisma.workoutSession.update({ where: { id: sessionId }, data: { notes: 'Écrit ailleurs' } }),
    );
  });

  it('écrire dans une AUTRE séance ne touche pas celle-ci', async () => {
    const sessionId = await newSession();
    const other = await newSession();
    await keeps(sessionId, () =>
      as().post(`/api/v1/workout-sessions/${other}/sets`).send(setBody(randomUUID())).expect(201),
    );
  });
});
