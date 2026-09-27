process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = process.env.CARLYS_E2E_LOG ?? 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR,
  type ApiSuccessEnvelope,
  type AuthResult,
  type FriendChallenge,
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
import { ENCOURAGEMENTS_PER_FRIEND_PER_DAY } from '../src/modules/community/application/encouragements.service';
import { reinitialiserDebit } from './support/throttle';

/**
 * Les canaux qui poussent une notification chez un ami — défis entre amis et
 * encouragements — sont bornés PAR PERSONNE, et la borne tient en parallèle.
 */
describe('Communauté : plafonds qui tiennent (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let tokenA: string;
  let tokenB: string;
  let userIdA: string;
  let userIdB: string;
  const suffix = randomUUID();
  const emailA = `e2e-com-surete-a-${suffix}@carlys.test`;
  const emailB = `e2e-com-surete-b-${suffix}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const as = (bearer: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${bearer}`),
    post: (url: string) => server().post(url).set('Authorization', `Bearer ${bearer}`),
  });
  const defier = (bearer: string, id: string, invitedUserIds: string[]) =>
    as(bearer).post('/api/v1/community/friend-challenges').send({
      id,
      title: 'Qui court le plus',
      metric: 'DISTANCE_METERS',
      durationDays: 7,
      invitedUserIds,
    });
  const encourager = () =>
    as(tokenA)
      .post('/api/v1/community/encouragements')
      .send({ recipientUserId: userIdB, message: 'Bravo !' });

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const register = async (mail: string, name: string) =>
      data<AuthResult>(
        (
          await server()
            .post('/api/v1/auth/register')
            .send({ email: mail, password: 'MotDePasseSolide42', displayName: name })
            .expect(201)
        ).body,
      );
    const a = await register(emailA, 'Alice');
    const b = await register(emailB, 'Boris');
    tokenA = a.tokens.accessToken;
    tokenB = b.tokens.accessToken;
    userIdA = a.user.id;
    userIdB = b.user.id;
    await as(tokenA).post('/api/v1/community/requests').send({ email: emailB }).expect(202);
    const recues = data<Array<{ id: string }>>(
      (await as(tokenB).get('/api/v1/community/requests').expect(200)).body,
    );
    await as(tokenB).post(`/api/v1/community/requests/${recues[0]?.id}/accept`).expect(204);
  });

  beforeEach(reinitialiserDebit);

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: [emailA, emailB] } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('défis entre amis : 15 créations PARALLÈLES n’ouvrent que le plafond, pas plus', async () => {
    const ids = Array.from({ length: 15 }, () => randomUUID());
    const reponses = await Promise.all(ids.map((id) => defier(tokenA, id, [userIdB])));
    const statuts = reponses.map((reponse) => reponse.status).sort();

    const ouverts = await prisma.friendChallenge.count({
      where: { creatorId: userIdA, status: 'OPEN' },
    });
    expect(ouverts).toBe(FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR);
    expect(statuts.filter((statut) => statut === 201)).toHaveLength(
      FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR,
    );
    expect(statuts.filter((statut) => statut === 403)).toHaveLength(
      15 - FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR,
    );
    // Autant d'invitations que de défis créés, pas une de plus.
    const invitations = await prisma.friendChallengeMember.count({
      where: { userId: userIdB, challenge: { creatorId: userIdA } },
    });
    expect(invitations).toBe(FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR);
  });

  it('le rejeu d’une création RÉUSSIE rend le défi, même plafond atteint', async () => {
    // Le plafond est atteint ICI, quel que soit l'ordre des tests (ou `-t`
    // seul) : les défis ouverts d'Alice sont complétés jusqu'à lui, puis un
    // de plus est refusé.
    let ouverts = await prisma.friendChallenge.count({
      where: { creatorId: userIdA, status: 'OPEN' },
    });
    for (; ouverts < FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR; ouverts += 1) {
      await defier(tokenA, randomUUID(), [userIdB]).expect(201);
    }
    await defier(tokenA, randomUUID(), [userIdB]).expect(403);
    const cree = await prisma.friendChallenge.findFirstOrThrow({
      where: { creatorId: userIdA, status: 'OPEN' },
    });

    const rejeu = await defier(tokenA, cree.id, [userIdB]).expect(201);
    expect(data<FriendChallenge>(rejeu.body).id).toBe(cree.id);

    // Le même identifiant, présenté par quelqu'un d'autre : conflit.
    await defier(tokenB, cree.id, [userIdA]).expect(409);
  });

  it('encouragements : 10 par minute et par adresse', async () => {
    const statuts: number[] = [];
    for (let i = 0; i < 11; i += 1) {
      statuts.push((await encourager()).status);
    }
    expect(statuts.slice(0, 10).every((statut) => statut === 201)).toBe(true);
    expect(statuts[10]).toBe(429);
  });

  it(`encouragements : ${ENCOURAGEMENTS_PER_FRIEND_PER_DAY} au même ami par jour, puis 429 sans rien écrire`, async () => {
    // Ceux déjà écrits (par le test précédent, s'il a tourné) sont comptés ;
    // on complète jusqu'au plafond, en remettant le débit par IP à zéro pour
    // ne voir QUE le plafond par ami.
    let deja = await prisma.encouragement.count({
      where: { senderId: userIdA, recipientId: userIdB },
    });
    while (deja < ENCOURAGEMENTS_PER_FRIEND_PER_DAY) {
      if (deja % 9 === 0) {
        await reinitialiserDebit();
      }
      await encourager().expect(201);
      deja += 1;
    }
    await reinitialiserDebit();

    const refus = await encourager().expect(429);
    expect(JSON.stringify(refus.body)).toContain('aujourd’hui');
    expect(
      await prisma.encouragement.count({ where: { senderId: userIdA, recipientId: userIdB } }),
    ).toBe(ENCOURAGEMENTS_PER_FRIEND_PER_DAY);

    // Le plafond est PAR AMI et glissant : les envois d'hier ne comptent plus.
    await prisma.encouragement.updateMany({
      where: { senderId: userIdA, recipientId: userIdB },
      data: { createdAt: new Date(Date.now() - 25 * 3_600_000) },
    });
    await encourager().expect(201);
  });
});
