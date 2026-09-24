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
  let userIdA: string;
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
    userIdA = a.user.id;
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

  it('le mot du créateur : découpé, daté, lu par l’invité, jamais réécrit par un rejeu', async () => {
    const challengeId = randomUUID();
    const avant = Date.now();
    const cree = data<FriendChallenge>(
      (
        await defier(tokenA, {
          id: challengeId,
          invitedUserIds: [userIdB],
          durationDays: 3,
          message: '  On verra qui tient la semaine.  ',
        }).expect(201)
      ).body,
    );
    expect(cree.message).toBe('On verra qui tient la semaine.');
    expect(cree.durationDays).toBe(3);
    // L'heure du message est celle du défi : un instant ISO UTC, maintenant.
    expect(cree.createdAt).toMatch(/Z$/);
    expect(Date.parse(cree.createdAt)).toBeGreaterThanOrEqual(avant - 1_000);
    expect(Date.parse(cree.createdAt)).toBeLessThanOrEqual(Date.now() + 1_000);
    // Le créateur est marqué, et c'est l'appelant ; l'invité ne l'est pas.
    expect(cree.members.find((m) => m.isMe)).toMatchObject({ isCreator: true, status: 'ACCEPTED' });
    expect(cree.members.find((m) => m.userId === userIdB)?.isCreator).toBe(false);

    // Rejeu avec un AUTRE mot : le défi est rendu tel qu'il a été créé.
    const rejoue = data<FriendChallenge>(
      (
        await defier(tokenA, {
          id: challengeId,
          invitedUserIds: [userIdB],
          durationDays: 3,
          message: 'Un autre mot',
        }).expect(201)
      ).body,
    );
    expect(rejoue.message).toBe('On verra qui tient la semaine.');

    // L'invité, qui n'a encore rien accepté, lit le mot au détail et dans sa
    // liste ; un non-membre ne voit toujours rien.
    const vu = data<FriendChallenge>(
      (await as(tokenB).get(`/api/v1/community/friend-challenges/${challengeId}`).expect(200)).body,
    );
    expect(vu).toMatchObject({
      message: 'On verra qui tient la semaine.',
      createdAt: cree.createdAt,
      durationDays: 3,
      myStatus: 'INVITED',
    });
    expect(vu.members.find((m) => m.isCreator)?.displayName).toBe('Alice');
    const siens = data<FriendChallenge[]>(
      (await as(tokenB).get('/api/v1/community/friend-challenges').expect(200)).body,
    );
    expect(siens.find((entry) => entry.id === challengeId)?.message).toBe(
      'On verra qui tient la semaine.',
    );
    await as(tokenC).get(`/api/v1/community/friend-challenges/${challengeId}`).expect(404);

    // Accepter rend la même forme, mot compris.
    const accepte = data<FriendChallenge>(
      (
        await as(tokenB)
          .post(`/api/v1/community/friend-challenges/${challengeId}/accept`)
          .expect(201)
      ).body,
    );
    expect(accepte).toMatchObject({
      message: 'On verra qui tient la semaine.',
      myStatus: 'ACCEPTED',
    });
  });

  it('le mot : 280 caractères APRÈS découpage, et un blanc vaut « pas de message »', async () => {
    // Boris crée ici : le plafond de défis ouverts d'Alice reste à ses épreuves.
    await defier(tokenB, { invitedUserIds: [userIdA], message: 'x'.repeat(281) }).expect(400);
    await defier(tokenB, { invitedUserIds: [userIdA], message: 42 }).expect(400);

    const pile = data<FriendChallenge>(
      (
        await defier(tokenB, {
          invitedUserIds: [userIdA],
          message: `  ${'x'.repeat(280)}  `,
        }).expect(201)
      ).body,
    );
    expect(pile.message).toHaveLength(280);

    const blanc = data<FriendChallenge>(
      (await defier(tokenB, { invitedUserIds: [userIdA], message: '   ' }).expect(201)).body,
    );
    expect(blanc.message).toBeNull();
    const enBase = await prisma.friendChallenge.findUniqueOrThrow({ where: { id: blanc.id } });
    expect(enBase.message).toBeNull();

    const sans = data<FriendChallenge>(
      (await defier(tokenB, { invitedUserIds: [userIdA] }).expect(201)).body,
    );
    expect(sans.message).toBeNull();
  });

  it('le mot se compte en POINTS DE CODE, comme le contrat publié', async () => {
    // 280 émojis simples : 560 unités UTF-16, mais 280 points de code. Le
    // contrat les refusait dès 141 ; l'API et lui disent désormais pareil.
    const emojis = data<FriendChallenge>(
      (await defier(tokenB, { invitedUserIds: [userIdA], message: '😀'.repeat(280) }).expect(201))
        .body,
    );
    expect([...(emojis.message ?? '')]).toHaveLength(280);
    await defier(tokenB, { invitedUserIds: [userIdA], message: '😀'.repeat(281) }).expect(400);

    // ❤️ = U+2764 + U+FE0F : deux points de code. 141 cœurs en font 282,
    // que `@MaxLength` laissait passer pour 141.
    await defier(tokenB, { invitedUserIds: [userIdA], message: '❤️'.repeat(141) }).expect(400);
  });

  it('un blocage tait le mot du créateur d’un défi ACCEPTÉ, dans les deux sens, sans le retirer', async () => {
    // Chloé devient l'amie d'Alice, puis la défie avec un mot. C'est Chloé
    // qui crée : le plafond de défis ouverts d'Alice reste à ses épreuves.
    await as(tokenC).post('/api/v1/community/requests').send({ email: emailA }).expect(202);
    const recues = data<Array<{ id: string; fromDisplayName: string }>>(
      (await as(tokenA).get('/api/v1/community/requests').expect(200)).body,
    );
    const deChloe = recues.find((demande) => demande.fromDisplayName === 'Chloé');
    await as(tokenA).post(`/api/v1/community/requests/${deChloe?.id}/accept`).expect(204);
    const challengeId = randomUUID();
    const mot = 'Tu vas encore perdre, comme d’habitude.';
    await defier(tokenC, { id: challengeId, invitedUserIds: [userIdA], message: mot }).expect(201);

    const lu = async (bearer: string) => ({
      detail: data<FriendChallenge>(
        (await as(bearer).get(`/api/v1/community/friend-challenges/${challengeId}`).expect(200))
          .body,
      ),
      liste: data<FriendChallenge[]>(
        (await as(bearer).get('/api/v1/community/friend-challenges').expect(200)).body,
      ).find((entry) => entry.id === challengeId),
    });
    expect((await lu(tokenA)).detail.message).toBe(mot);
    // Alice ACCEPTE : c'est un défi en cours, son classement est un résultat
    // partagé. (Une invitation encore en attente, elle, disparaîtrait : voir
    // l'épreuve suivante.)
    await as(tokenA).post(`/api/v1/community/friend-challenges/${challengeId}/accept`).expect(201);

    // Alice bloque Chloé : le geste de protection documenté. Le défi reste,
    // avec son titre et son classement ; le texte libre suit la règle du fil.
    await as(tokenA).post(`/api/v1/community/blocks/${userIdC}`).expect(204);
    const bloqueuse = await lu(tokenA);
    expect(bloqueuse.detail).toMatchObject({ message: null, title: 'Qui court le plus' });
    expect(bloqueuse.detail.members.find((m) => m.isCreator)?.userId).toBe(userIdC);
    expect(bloqueuse.liste?.message).toBeNull();
    // La créatrice, elle, lit toujours son propre mot.
    expect((await lu(tokenC)).detail.message).toBe(mot);

    // Le signalement reste possible : le cliché vient de la base, pas de la
    // réponse qui vient de taire le mot.
    const signalement = await as(tokenA)
      .post('/api/v1/community/reports')
      .send({ reportedUserId: userIdC, friendChallengeId: challengeId, reason: 'HARCELEMENT' })
      .expect(201);
    const enBase = await prisma.communityReport.findUniqueOrThrow({
      where: { id: data<{ id: string }>(signalement.body).id },
    });
    expect(enBase.friendChallengeMessage).toBe(mot);

    // Dans l'AUTRE sens : Chloé bloque Alice (après le déblocage d'Alice).
    // Le mot se tait aussi pour Alice : le blocage se lit dans les deux sens.
    await as(tokenA).delete(`/api/v1/community/blocks/${userIdC}`).expect(204);
    expect((await lu(tokenA)).detail.message).toBe(mot);
    await as(tokenC).post(`/api/v1/community/blocks/${userIdA}`).expect(204);
    expect((await lu(tokenA)).detail.message).toBeNull();
    // Accepter (rejoué) rend la même forme, mot masqué compris.
    const accepte = data<FriendChallenge>(
      (
        await as(tokenA)
          .post(`/api/v1/community/friend-challenges/${challengeId}/accept`)
          .expect(201)
      ).body,
    );
    expect(accepte.message).toBeNull();
    await as(tokenC).delete(`/api/v1/community/blocks/${userIdA}`).expect(204);
  });

  it('une INVITATION d’un créateur bloqué disparaît : liste, détail, acceptation, même 404', async () => {
    // Deux comptes à part : bloquer retire l'amitié, et les épreuves
    // précédentes ont besoin de la leur.
    const prefixe = `e2e-fc-invit-${randomUUID()}`;
    const inscrire = async (nom: string) =>
      data<AuthResult>(
        (
          await server()
            .post('/api/v1/auth/register')
            .send({
              email: `${prefixe}-${nom}@carlys.test`,
              password: 'MotDePasseSolide42',
              displayName: nom,
            })
            .expect(201)
        ).body,
      );
    const dora = await inscrire('dora');
    const eliot = await inscrire('eliot');
    try {
      await as(eliot.tokens.accessToken)
        .post('/api/v1/community/requests')
        .send({ email: dora.user.email })
        .expect(202);
      const recues = data<Array<{ id: string }>>(
        (await as(dora.tokens.accessToken).get('/api/v1/community/requests').expect(200)).body,
      );
      await as(dora.tokens.accessToken)
        .post(`/api/v1/community/requests/${recues[0]?.id}/accept`)
        .expect(204);
      const challengeId = randomUUID();
      await defier(eliot.tokens.accessToken, {
        id: challengeId,
        invitedUserIds: [dora.user.id],
        message: 'Viens perdre.',
      }).expect(201);

      const doraVoit = async () => ({
        liste: data<FriendChallenge[]>(
          (await as(dora.tokens.accessToken).get('/api/v1/community/friend-challenges').expect(200))
            .body,
        ).some((entry) => entry.id === challengeId),
        detail: (
          await as(dora.tokens.accessToken).get(
            `/api/v1/community/friend-challenges/${challengeId}`,
          )
        ).status,
      });
      expect(await doraVoit()).toEqual({ liste: true, detail: 200 });

      // Dora bloque Éliot : son invitation disparaît partout, avec le 404
      // d'un défi qui n'existe pas — le même message, sans oracle.
      await as(dora.tokens.accessToken)
        .post(`/api/v1/community/blocks/${eliot.user.id}`)
        .expect(204);
      expect(await doraVoit()).toEqual({ liste: false, detail: 404 });
      const inconnu = await as(dora.tokens.accessToken)
        .get(`/api/v1/community/friend-challenges/${randomUUID()}`)
        .expect(404);
      const accepte = await as(dora.tokens.accessToken)
        .post(`/api/v1/community/friend-challenges/${challengeId}/accept`)
        .expect(404);
      const erreur = (body: unknown) => (body as { error: { message: string } }).error.message;
      expect(erreur(accepte.body)).toBe(erreur(inconnu.body));
      expect(erreur(accepte.body)).toBe('Défi introuvable.');
      // Rien n'a été écrit : elle reste invitée, pas membre.
      const ligne = await prisma.friendChallengeMember.findUniqueOrThrow({
        where: { challengeId_userId: { challengeId, userId: dora.user.id } },
      });
      expect(ligne.status).toBe('INVITED');
      // Le signalement, lui, reste possible : c'est le geste de protection.
      await as(dora.tokens.accessToken)
        .post('/api/v1/community/reports')
        .send({ reportedUserId: eliot.user.id, friendChallengeId: challengeId, reason: 'SPAM' })
        .expect(201);

      // Le créateur voit toujours son défi, invitée comprise : la règle
      // porte sur l'invitation REÇUE.
      const siens = data<FriendChallenge>(
        (
          await as(eliot.tokens.accessToken)
            .get(`/api/v1/community/friend-challenges/${challengeId}`)
            .expect(200)
        ).body,
      );
      expect(siens.members.find((m) => m.userId === dora.user.id)?.status).toBe('INVITED');

      // Débloquer la fait revenir ; dans l'AUTRE sens, elle disparaît aussi.
      await as(dora.tokens.accessToken)
        .delete(`/api/v1/community/blocks/${eliot.user.id}`)
        .expect(204);
      expect(await doraVoit()).toEqual({ liste: true, detail: 200 });
      await as(eliot.tokens.accessToken)
        .post(`/api/v1/community/blocks/${dora.user.id}`)
        .expect(204);
      expect(await doraVoit()).toEqual({ liste: false, detail: 404 });
      await as(dora.tokens.accessToken)
        .post(`/api/v1/community/friend-challenges/${challengeId}/accept`)
        .expect(404);

      // REFUSER d'abord ne rouvre rien : une fois le blocage posé, le défi
      // refusé disparaît aussi, et le réaccepter répond le même 404.
      const statutDeDora = async () =>
        (
          await prisma.friendChallengeMember.findUniqueOrThrow({
            where: { challengeId_userId: { challengeId, userId: dora.user.id } },
          })
        ).status;
      const detailDeDora = () =>
        as(dora.tokens.accessToken).get(`/api/v1/community/friend-challenges/${challengeId}`);
      const accepterPourDora = () =>
        as(dora.tokens.accessToken).post(
          `/api/v1/community/friend-challenges/${challengeId}/accept`,
        );
      await as(eliot.tokens.accessToken)
        .delete(`/api/v1/community/blocks/${dora.user.id}`)
        .expect(204);
      await as(dora.tokens.accessToken)
        .delete(`/api/v1/community/friend-challenges/${challengeId}/join`)
        .expect(204);
      expect(await statutDeDora()).toBe('DECLINED');
      await as(dora.tokens.accessToken)
        .post(`/api/v1/community/blocks/${eliot.user.id}`)
        .expect(204);
      await detailDeDora().expect(404);
      const reaccepte = await accepterPourDora().expect(404);
      expect(erreur(reaccepte.body)).toBe('Défi introuvable.');
      expect(await statutDeDora()).toBe('DECLINED');

      // QUITTER non plus : accepté, quitté, puis bloqué — même 404.
      await as(dora.tokens.accessToken)
        .delete(`/api/v1/community/blocks/${eliot.user.id}`)
        .expect(204);
      await accepterPourDora().expect(201);
      await as(dora.tokens.accessToken)
        .delete(`/api/v1/community/friend-challenges/${challengeId}/join`)
        .expect(204);
      expect(await statutDeDora()).toBe('LEFT');
      await as(eliot.tokens.accessToken)
        .post(`/api/v1/community/blocks/${dora.user.id}`)
        .expect(204);
      await detailDeDora().expect(404);
      expect(erreur((await accepterPourDora().expect(404)).body)).toBe('Défi introuvable.');
      expect(await statutDeDora()).toBe('LEFT');
    } finally {
      await prisma.user.deleteMany({ where: { email: { startsWith: prefixe } } });
    }
  });
});
