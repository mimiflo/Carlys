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

/**
 * DÉFIS ENTRE AMIS : individuels, invités un par un, clos tout seuls.
 *
 * Ce qui se vérifie ici, et qui a justifié des tables séparées des défis
 * collectifs : on n'invite que des amis, partir RETIRE du classement (là où
 * quitter un défi collectif laisse sa contribution au groupe), et la clôture
 * ÉCRIT un résultat au lieu de laisser le défi cesser d'être lu.
 */
describe('Défis entre amis (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let tokenA: string;
  let tokenB: string;
  let tokenC: string;
  let userIdB: string;
  let userIdC: string;
  const emailA = `e2e-fc-a-${randomUUID()}@carlys.test`;
  const emailB = `e2e-fc-b-${randomUUID()}@carlys.test`;
  const emailC = `e2e-fc-c-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());
  const as = (bearer: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${bearer}`),
    post: (url: string) => server().post(url).set('Authorization', `Bearer ${bearer}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${bearer}`),
  });

  const defier = (bearer: string, body: Record<string, unknown>) =>
    as(bearer)
      .post('/api/v1/community/friend-challenges')
      .send({
        id: randomUUID(),
        title: 'Qui court le plus',
        metric: 'DISTANCE_METERS',
        durationDays: 7,
        ...body,
      });

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
    const c = await register(emailC, 'Chloé');
    tokenA = a.tokens.accessToken;
    tokenB = b.tokens.accessToken;
    tokenC = c.tokens.accessToken;
    userIdB = b.user.id;
    userIdC = c.user.id;

    // Alice et Boris sont amis. Chloé ne l'est de personne : c'est elle qui
    // prouve qu'on ne défie pas un inconnu.
    await as(tokenA).post('/api/v1/community/requests').send({ email: emailB }).expect(202);
    const recues = data<Array<{ id: string }>>(
      (await as(tokenB).get('/api/v1/community/requests').expect(200)).body,
    );
    await as(tokenB).post(`/api/v1/community/requests/${recues[0]?.id}/accept`).expect(204);
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: [emailA, emailB, emailC] } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('on ne défie QUE ses amis, et le refus ne dit pas pourquoi', async () => {
    // Chloé n'est pas l'amie d'Alice : 403, sans distinguer « pas amie » de
    // « t'a bloquée » — sinon l'invitation devient un détecteur de blocage.
    const refus = await defier(tokenA, { invitedUserIds: [userIdC] }).expect(403);
    expect(JSON.stringify(refus.body)).toContain('tes amis');
  });

  it('inviter, accepter, contribuer, classer', async () => {
    const challengeId = randomUUID();
    const cree = data<FriendChallenge>(
      (await defier(tokenA, { id: challengeId, invitedUserIds: [userIdB] }).expect(201)).body,
    );
    // Le créateur est membre ACCEPTÉ d'office ; l'invité attend.
    expect(cree.myStatus).toBe('ACCEPTED');
    expect(cree.members.find((m) => m.userId === userIdB)?.status).toBe('INVITED');
    expect(cree.unit).toBe('mètres');

    // Rejeu de la création : le même défi, pas un second.
    await defier(tokenA, { id: challengeId, invitedUserIds: [userIdB] }).expect(201);
    const miens = data<FriendChallenge[]>(
      (await as(tokenA).get('/api/v1/community/friend-challenges').expect(200)).body,
    );
    expect(miens.filter((entry) => entry.id === challengeId)).toHaveLength(1);

    // Boris accepte, puis court 3 km.
    await as(tokenB).post(`/api/v1/community/friend-challenges/${challengeId}/accept`).expect(201);
    const sessionId = randomUUID();
    await as(tokenB)
      .post('/api/v1/workout-sessions')
      .send({ id: sessionId, startedAt: new Date().toISOString() })
      .expect(201);
    await as(tokenB)
      .post(`/api/v1/workout-sessions/${sessionId}/sets`)
      .send({
        id: randomUUID(),
        exerciseName: 'Course',
        position: 0,
        distanceMeters: 3_000,
        completedAt: new Date().toISOString(),
      })
      .expect(201);
    await as(tokenB).post(`/api/v1/workout-sessions/${sessionId}/complete`).send({}).expect(200);

    const vu = data<FriendChallenge>(
      (await as(tokenA).get(`/api/v1/community/friend-challenges/${challengeId}`).expect(200)).body,
    );
    const boris = vu.members.find((member) => member.userId === userIdB);
    // 3 000 mètres, et la première place : le classement est INDIVIDUEL.
    expect(boris?.contribution).toBe(3_000);
    expect(boris?.rank).toBe(1);
    // Alice n'a rien fait : deuxième, à zéro. Elle n'est pas hors classement.
    expect(vu.members.find((member) => member.isMe)?.rank).toBe(2);
  });

  it('quitter RETIRE du classement, contrairement à un défi collectif', async () => {
    const challengeId = randomUUID();
    await defier(tokenA, { id: challengeId, invitedUserIds: [userIdB] }).expect(201);
    await as(tokenB).post(`/api/v1/community/friend-challenges/${challengeId}/accept`).expect(201);

    await as(tokenB).delete(`/api/v1/community/friend-challenges/${challengeId}/join`).expect(204);

    const vu = data<FriendChallenge>(
      (await as(tokenA).get(`/api/v1/community/friend-challenges/${challengeId}`).expect(200)).body,
    );
    const boris = vu.members.find((member) => member.userId === userIdB);
    expect(boris?.status).toBe('LEFT');
    // Plus de rang : un classement individuel ne garde pas les partants. Une
    // contribution versée à un défi COLLECTIF, elle, reste acquise au groupe.
    expect(boris?.rank).toBeNull();

    // Et le défi disparaît de SA liste : une décision prise ne se revoit pas.
    const siens = data<FriendChallenge[]>(
      (await as(tokenB).get('/api/v1/community/friend-challenges').expect(200)).body,
    );
    expect(siens.some((entry) => entry.id === challengeId)).toBe(false);
  });

  it('un défi échu se RÈGLE à la lecture, une seule fois', async () => {
    const challengeId = randomUUID();
    await defier(tokenA, { id: challengeId, invitedUserIds: [userIdB] }).expect(201);
    await as(tokenB).post(`/api/v1/community/friend-challenges/${challengeId}/accept`).expect(201);
    // La fin est calculée par le serveur : pour la faire arriver, on recule
    // les bornes en base — c'est le seul moyen honnête de tester une clôture
    // qui n'a aucune tâche planifiée.
    await prisma.friendChallenge.update({
      where: { id: challengeId },
      data: {
        startsAt: new Date(Date.now() - 8 * 24 * 3_600_000),
        endsAt: new Date(Date.now() - 24 * 3_600_000),
      },
    });

    // Deux lectures SIMULTANÉES : une seule doit régler.
    const [premier, second] = await Promise.all([
      as(tokenA).get(`/api/v1/community/friend-challenges/${challengeId}`).expect(200),
      as(tokenB).get(`/api/v1/community/friend-challenges/${challengeId}`).expect(200),
    ]);
    expect(data<FriendChallenge>(premier.body).status).toBe('CLOSED');
    expect(data<FriendChallenge>(second.body).status).toBe('CLOSED');

    const enBase = await prisma.friendChallenge.findUniqueOrThrow({ where: { id: challengeId } });
    expect(enBase.closedAt).not.toBeNull();
    // Les rangs sont FIGÉS : ils ne bougeront plus, même si quelqu'un
    // continue à s'entraîner.
    const membres = await prisma.friendChallengeMember.findMany({ where: { challengeId } });
    expect(membres.every((membre) => membre.finalRank !== null)).toBe(true);

    // Et on n'accepte plus un défi terminé.
    await as(tokenB).post(`/api/v1/community/friend-challenges/${challengeId}/accept`).expect(404);
  });

  it('plafonne les défis ouverts d’un même créateur', async () => {
    // Sans ce plafond, l'invitation devient un canal d'envoi de messages
    // vers quelqu'un qui ne l'a pas demandé.
    const alice = await prisma.user.findUniqueOrThrow({ where: { email: emailA } });
    // Compté comme le service le compte : OUVERTS et non échus. Les défis
    // clos des épreuves précédentes ne doivent pas peser sur ce plafond.
    const ouverts = await prisma.friendChallenge.count({
      where: { creatorId: alice.id, status: 'OPEN', endsAt: { gte: new Date() } },
    });
    const crees: string[] = [];
    for (let i = ouverts; i < FRIEND_CHALLENGE_MAX_OPEN_PER_CREATOR; i += 1) {
      const id = randomUUID();
      crees.push(id);
      await defier(tokenA, { id, invitedUserIds: [userIdB] }).expect(201);
    }
    const refus = await defier(tokenA, { invitedUserIds: [userIdB] }).expect(403);
    expect(JSON.stringify(refus.body)).toContain('défis en cours');

    // Le plafond est rendu à l'épreuve suivante : il compte les défis
    // OUVERTS, et ceux-ci n'ont plus de raison de l'être.
    await prisma.friendChallenge.deleteMany({ where: { id: { in: crees } } });
  });

  it('le défi des autres est INTROUVABLE, pas interdit', async () => {
    const challengeId = randomUUID();
    await defier(tokenA, { id: challengeId, invitedUserIds: [userIdB] }).expect(201);

    // Chloé n'en est pas membre : 404, jamais 403 — un 403 confirmerait que
    // ce défi existe, et de quoi il parle.
    await as(tokenC).get(`/api/v1/community/friend-challenges/${challengeId}`).expect(404);
    await as(tokenC).post(`/api/v1/community/friend-challenges/${challengeId}/accept`).expect(404);
  });

  it('refuse une durée hors des trois offertes, et un défi sans personne', async () => {
    await defier(tokenA, { invitedUserIds: [userIdB], durationDays: 400 }).expect(400);
    await defier(tokenA, { invitedUserIds: [] }).expect(400);
  });
});
