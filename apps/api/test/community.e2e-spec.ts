process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type CommunityChallenge,
  type CommunityFriend,
  type CommunityProfile,
  type Encouragement,
  type FriendRequest,
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
import {
  MONTHLY_CHALLENGE_CATALOG,
  monthWindowUtc,
} from '../src/modules/community/domain/challenge-catalog';

/**
 * Communauté : demandes d'ami opaques (pas d'énumération d'adresses),
 * confidentialité décidée côté serveur, encouragements réservés aux amis,
 * défis à progression collective.
 */
describe('Communauté (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let tokenA: string;
  let tokenB: string;
  let tokenC: string;
  let userIdB: string;

  const emailA = `e2e-communaute-a-${randomUUID()}@carlys.test`;
  const emailB = `e2e-communaute-b-${randomUUID()}@carlys.test`;
  const emailC = `e2e-communaute-c-${randomUUID()}@carlys.test`;
  const challengeSlug = `e2e-defi-${randomUUID()}`;
  let challengeId: string;
  /** Le jeu du mois est créé par l'API elle-même : la suite part d'un mois vierge. */
  const currentMonth = monthWindowUtc(new Date()).month;
  const catalogSlugs = MONTHLY_CHALLENGE_CATALOG.map((template) => template.slug);
  const monthlyRows = () =>
    prisma.communityChallenge.findMany({
      where: { month: currentMonth, slug: { in: catalogSlugs } },
    });

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const authed = (token: string) => ({
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

    const register = async (email: string, displayName: string): Promise<AuthResult> => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ email, password: 'MotDePasseSolide42', displayName })
        .expect(201);
      return data<AuthResult>(response.body);
    };

    const a = await register(emailA, 'Alice');
    const b = await register(emailB, 'Boris');
    const c = await register(emailC, 'Chloé');
    tokenA = a.tokens.accessToken;
    tokenB = b.tokens.accessToken;
    tokenC = c.tokens.accessToken;
    userIdB = b.user.id;

    // Mois vierge : la création paresseuse doit se voir ici, pas être héritée.
    await prisma.communityChallenge.deleteMany({
      where: { month: currentMonth, slug: { in: catalogSlugs } },
    });

    // Défi fixture — la suite ne dépend jamais du seed (base CI vierge).
    const challenge = await prisma.communityChallenge.create({
      data: {
        slug: challengeSlug,
        month: currentMonth,
        kind: 'SPORT',
        title: 'Défi e2e',
        description: 'Défi collectif de test.',
        target: 2,
        endsAt: new Date(Date.now() + 7 * 24 * 3_600_000),
      },
    });
    challengeId = challenge.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: [emailA, emailB, emailC] } } });
    await prisma.communityChallenge.deleteMany({ where: { slug: challengeSlug } });
    await prisma.communityChallenge.deleteMany({
      where: { month: currentMonth, slug: { in: catalogSlugs } },
    });
    await prisma.$disconnect();
    await app.close();
  });

  it('refuse les requêtes sans authentification', async () => {
    await request(app.getHttpServer()).get('/api/v1/community/friends').expect(401);
  });

  it('une demande vers une adresse INCONNUE répond exactement comme une vraie', async () => {
    await authed(tokenA)
      .post('/api/v1/community/requests')
      .send({ email: `inconnu-${randomUUID()}@carlys.test` })
      .expect(202);
  });

  it('le code ami fait le tour complet : profil → aperçu → demande → amis', async () => {
    // Mon profil communautaire porte mon code, sous forme canonique.
    const profileB = data<{ friendCode: string }>(
      (await authed(tokenB).get('/api/v1/community/profile').expect(200)).body,
    );
    expect(profileB.friendCode).toMatch(/^[23456789ACDEFHJKMNPRTUVWXY]{8}$/);

    // L'aperçu confirme le porteur avant l'envoi — forme affichée acceptée.
    const displayed = `${profileB.friendCode.slice(0, 4)}-${profileB.friendCode.slice(4)}`;
    const preview = data<{ displayName: string }>(
      (
        await authed(tokenA)
          .get(`/api/v1/community/friend-codes/${encodeURIComponent(displayed)}`)
          .expect(200)
      ).body,
    );
    expect(preview.displayName).toBe('Boris');

    // Demande par code (charge utile de QR), acceptation, amitié.
    await authed(tokenA)
      .post('/api/v1/community/requests')
      .send({ friendCode: `carlys:friend:${profileB.friendCode}` })
      .expect(202);
    const received = data<FriendRequest[]>(
      (await authed(tokenB).get('/api/v1/community/requests').expect(200)).body,
    );
    expect(received).toHaveLength(1);
    await authed(tokenB).post(`/api/v1/community/requests/${received[0]?.id}/accept`).expect(204);
    const friendsOfA = data<CommunityFriend[]>(
      (await authed(tokenA).get('/api/v1/community/friends').expect(200)).body,
    );
    expect(friendsOfA.map((friend) => friend.displayName)).toEqual(['Boris']);

    // Le scénario par e-mail, plus bas, repart d'une page blanche : sans ce
    // retrait, la demande suivante ne créerait rien (déjà amis) et la liste
    // des demandes reçues resterait vide.
    await authed(tokenA).delete(`/api/v1/community/friends/${userIdB}`).expect(204);
  });

  it('un code inconnu : aperçu en 404, demande muette en 202', async () => {
    await authed(tokenA).get('/api/v1/community/friend-codes/AC23DEF4').expect(404);
    await authed(tokenA)
      .post('/api/v1/community/requests')
      .send({ friendCode: 'AC23DEF4' })
      .expect(202);
  });

  it('e-mail ET code à la fois : requête refusée, il faut choisir', async () => {
    await authed(tokenA)
      .post('/api/v1/community/requests')
      .send({ email: emailB, friendCode: 'AC23DEF4' })
      .expect(400);
    await authed(tokenA).post('/api/v1/community/requests').send({}).expect(400);
  });

  it('demande, réception, acceptation : les deux deviennent amis', async () => {
    await authed(tokenA).post('/api/v1/community/requests').send({ email: emailB }).expect(202);

    const received = data<FriendRequest[]>(
      (await authed(tokenB).get('/api/v1/community/requests').expect(200)).body,
    );
    expect(received).toHaveLength(1);
    expect(received[0]?.fromDisplayName).toBe('Alice');

    await authed(tokenB).post(`/api/v1/community/requests/${received[0]?.id}/accept`).expect(204);

    const friendsOfA = data<CommunityFriend[]>(
      (await authed(tokenA).get('/api/v1/community/friends').expect(200)).body,
    );
    expect(friendsOfA.map((friend) => friend.displayName)).toEqual(['Boris']);
    const friendsOfB = data<CommunityFriend[]>(
      (await authed(tokenB).get('/api/v1/community/friends').expect(200)).body,
    );
    expect(friendsOfB.map((friend) => friend.displayName)).toEqual(['Alice']);
  });

  it('rejouer la même demande une fois amis ne crée rien de nouveau', async () => {
    await authed(tokenA).post('/api/v1/community/requests').send({ email: emailB }).expect(202);
    const received = data<FriendRequest[]>(
      (await authed(tokenB).get('/api/v1/community/requests').expect(200)).body,
    );
    expect(received).toHaveLength(0);
  });

  it('la progression ne sort du serveur QUE si elle est partagée', async () => {
    // Boris termine une séance : sa progression existe.
    const sessionId = randomUUID();
    await authed(tokenB)
      .post('/api/v1/workout-sessions')
      .send({ id: sessionId, name: 'Push e2e', startedAt: new Date().toISOString() })
      .expect(201);
    await authed(tokenB)
      .post(`/api/v1/workout-sessions/${sessionId}/complete`)
      .send({})
      .expect(200);

    // Partagée (défaut) : Alice la voit.
    let [boris] = data<CommunityFriend[]>(
      (await authed(tokenA).get('/api/v1/community/friends').expect(200)).body,
    );
    expect(boris?.sharesProgress).toBe(true);
    expect(boris?.weeklySessions).toBe(1);
    expect(boris?.streakDays).toBe(1);

    // Boris passe en privé : Alice ne voit plus RIEN — null, pas zéro.
    const profile = data<CommunityProfile>(
      (
        await authed(tokenB)
          .patch('/api/v1/community/profile')
          .send({ sharesProgress: false })
          .expect(200)
      ).body,
    );
    expect(profile.sharesProgress).toBe(false);

    [boris] = data<CommunityFriend[]>(
      (await authed(tokenA).get('/api/v1/community/friends').expect(200)).body,
    );
    expect(boris?.sharesProgress).toBe(false);
    expect(boris?.streakDays).toBeNull();
    expect(boris?.weeklySessions).toBeNull();
  });

  it('encourager : réservé aux amis, et le fil du destinataire le reçoit', async () => {
    // Chloé n'est pas amie avec Boris : refus.
    await authed(tokenC)
      .post('/api/v1/community/encouragements')
      .send({ recipientUserId: userIdB, message: 'Bravo !' })
      .expect(403);

    // Alice est amie : accepté, et Boris le lit dans son fil.
    await authed(tokenA)
      .post('/api/v1/community/encouragements')
      .send({ recipientUserId: userIdB, message: 'Belle séance, Boris !' })
      .expect(201);

    const feed = data<Encouragement[]>(
      (await authed(tokenB).get('/api/v1/community/feed').expect(200)).body,
    );
    expect(feed).toHaveLength(1);
    expect(feed[0]?.fromDisplayName).toBe('Alice');
    expect(feed[0]?.message).toBe('Belle séance, Boris !');
  });

  it('les défis du mois se créent tout seuls à la première lecture, une fois, même en parallèle', async () => {
    // Le défi fixture vit dans le même mois : il ne doit pas faire croire que
    // le jeu du catalogue est déjà là.
    expect(await monthlyRows()).toHaveLength(0);

    // Cinq lectures CONCURRENTES d'un mois vierge : un seul jeu en base.
    const responses = await Promise.all(
      Array.from({ length: 5 }, () =>
        authed(tokenA).get('/api/v1/community/challenges').expect(200),
      ),
    );
    const rows = await monthlyRows();
    expect(rows.map((row) => row.slug).sort()).toEqual([...catalogSlugs].sort());

    // Chaque lecture voit le jeu complet, ouvert jusqu'à la fin du mois,
    // que personne n'a encore rejoint.
    for (const response of responses) {
      const challenges = data<CommunityChallenge[]>(response.body);
      for (const template of MONTHLY_CHALLENGE_CATALOG) {
        const monthly = challenges.find((entry) => entry.title === template.title);
        expect(monthly).toBeDefined();
        expect(monthly).toMatchObject({
          kind: template.kind,
          target: template.target,
          joined: false,
          participants: 0,
          progress: 0,
        });
        expect(new Date(monthly?.endsAt ?? 0).getTime()).toBeGreaterThan(Date.now());
      }
    }

    // Une lecture de plus, par quelqu'un d'autre, ne recrée rien.
    await authed(tokenB).get('/api/v1/community/challenges').expect(200);
    expect(await monthlyRows()).toHaveLength(catalogSlugs.length);
  });

  it('défi collectif : rejoindre, contribuer par une séance, quitter', async () => {
    // Alice rejoint (idempotent : rejoué sans doublon).
    let challenge = data<CommunityChallenge>(
      (await authed(tokenA).post(`/api/v1/community/challenges/${challengeId}/join`).expect(201))
        .body,
    );
    expect(challenge.joined).toBe(true);
    expect(challenge.participants).toBe(1);
    expect(challenge.progress).toBe(0);

    // Une séance terminée par Alice contribue au défi SPORT (target 2 → 0,5).
    const sessionId = randomUUID();
    await authed(tokenA)
      .post('/api/v1/workout-sessions')
      .send({ id: sessionId, name: 'Défi e2e', startedAt: new Date().toISOString() })
      .expect(201);
    await authed(tokenA)
      .post(`/api/v1/workout-sessions/${sessionId}/complete`)
      .send({})
      .expect(200);

    const challenges = data<CommunityChallenge[]>(
      (await authed(tokenA).get('/api/v1/community/challenges').expect(200)).body,
    );
    const mine = challenges.find((entry) => entry.id === challengeId);
    expect(mine?.progress).toBe(0.5);

    // Quitter : la carte repasse « non rejointe » pour Alice.
    challenge = data<CommunityChallenge>(
      (await authed(tokenA).delete(`/api/v1/community/challenges/${challengeId}/join`).expect(200))
        .body,
    );
    expect(challenge.joined).toBe(false);
    expect(challenge.participants).toBe(0);
  });

  it('défi CULTURE : une première réponse juste contribue, le rejeu non', async () => {
    // Défi culturel fixture, rejoint par Alice.
    const cultureSlug = `e2e-defi-culture-${randomUUID()}`;
    const culture = await prisma.communityChallenge.create({
      data: {
        slug: cultureSlug,
        month: currentMonth,
        kind: 'CULTURE',
        title: 'Défi culturel e2e',
        description: 'Cinq questions par jour.',
        target: 2,
        endsAt: new Date(Date.now() + 7 * 24 * 3_600_000),
      },
    });
    await authed(tokenA).post(`/api/v1/community/challenges/${culture.id}/join`).expect(201);

    const answer = { lessonId: 'lecon-dos', answeredOn: '2026-08-11', correct: true };
    await authed(tokenA).post('/api/v1/community/quiz-answers').send(answer).expect(204);
    // REJOUER la même réponse : aucune contribution supplémentaire.
    await authed(tokenA).post('/api/v1/community/quiz-answers').send(answer).expect(204);
    // Une réponse FAUSSE le lendemain : enregistrée, pas comptée.
    await authed(tokenA)
      .post('/api/v1/community/quiz-answers')
      .send({ lessonId: 'lecon-dos', answeredOn: '2026-08-12', correct: false })
      .expect(204);

    const challenges = data<CommunityChallenge[]>(
      (await authed(tokenA).get('/api/v1/community/challenges').expect(200)).body,
    );
    const mine = challenges.find((entry) => entry.id === culture.id);
    expect(mine?.progress).toBe(0.5); // 1 bonne réponse / objectif 2.

    await prisma.communityChallenge.deleteMany({ where: { slug: cultureSlug } });
  });

  it('retirer un ami est idempotent, et coupe les encouragements', async () => {
    await authed(tokenA).delete(`/api/v1/community/friends/${userIdB}`).expect(204);
    await authed(tokenA).delete(`/api/v1/community/friends/${userIdB}`).expect(204);

    await authed(tokenA)
      .post('/api/v1/community/encouragements')
      .send({ recipientUserId: userIdB, message: 'On n’est plus amis.' })
      .expect(403);
  });
});
