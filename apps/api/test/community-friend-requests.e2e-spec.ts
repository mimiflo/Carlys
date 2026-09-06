process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiErrorEnvelope,
  type ApiSuccessEnvelope,
  type AuthResult,
  type CommunityFriend,
  type CommunityProfile,
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

/** Limite dédiée de POST /community/requests (voir CommunityController). */
const FRIEND_REQUEST_LIMIT = 10;

/**
 * Demandes d'ami : refus OPPOSABLE et limite de débit dédiée.
 *
 * Suite ISOLÉE, exprès : POST /community/requests porte un throttle de
 * 10 requêtes / 60 s par adresse, et le seau vit dans l'application. Le
 * dernier scénario consomme tout le budget pour voir le 429 ; il ne doit
 * donc partager son application avec aucune autre suite, et les scénarios
 * qui le précèdent comptent leurs demandes.
 */
describe('Demandes d’ami : refus opposable et limite de débit (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let tokenA: string;
  let tokenB: string;
  let requestsSent = 0;

  const emailA = `e2e-refus-a-${randomUUID()}@carlys.test`;
  const emailB = `e2e-refus-b-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const errorOf = (body: unknown): ApiErrorEnvelope['error'] => (body as ApiErrorEnvelope).error;
  const authed = (token: string) => ({
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${token}`),
  });
  /** Toute demande passe par ici : c'est le compteur du budget de la suite. */
  const sendRequest = (token: string, body: { email?: string; friendCode?: string }) => {
    requestsSent += 1;
    return authed(token).post('/api/v1/community/requests').send(body);
  };
  const receivedBy = async (token: string): Promise<FriendRequest[]> =>
    data<FriendRequest[]>((await authed(token).get('/api/v1/community/requests').expect(200)).body);

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
    tokenA = (await register(emailA, 'Alice')).tokens.accessToken;
    tokenB = (await register(emailB, 'Boris')).tokens.accessToken;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: [emailA, emailB] } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('un refus rend le demandeur muet : redemander ne fait rien réapparaître', async () => {
    await sendRequest(tokenA, { email: emailB }).expect(202);
    const [received] = await receivedBy(tokenB);
    expect(received?.fromDisplayName).toBe('Alice');
    await authed(tokenB).post(`/api/v1/community/requests/${received?.id}/decline`).expect(204);

    // Alice redemande par e-mail : 202 opaque, et Boris ne voit RIEN.
    await sendRequest(tokenA, { email: emailB }).expect(202);
    expect(await receivedBy(tokenB)).toHaveLength(0);

    // Par code ami non plus : le refus tient, quel que soit le chemin.
    const profileB = data<CommunityProfile>(
      (await authed(tokenB).get('/api/v1/community/profile').expect(200)).body,
    );
    await sendRequest(tokenA, { friendCode: profileB.friendCode }).expect(202);
    expect(await receivedBy(tokenB)).toHaveLength(0);
  });

  it('celui qui a refusé peut prendre contact : la demande repart dans son sens', async () => {
    await sendRequest(tokenB, { email: emailA }).expect(202);
    const [received] = await receivedBy(tokenA);
    expect(received?.fromDisplayName).toBe('Boris');
    await authed(tokenA).post(`/api/v1/community/requests/${received?.id}/accept`).expect(204);

    const friendsOfB = data<CommunityFriend[]>(
      (await authed(tokenB).get('/api/v1/community/friends').expect(200)).body,
    );
    expect(friendsOfB.map((friend) => friend.displayName)).toEqual(['Alice']);
  });

  it('au-delà de 10 demandes par minute, la route répond 429, les autres non', async () => {
    while (requestsSent < FRIEND_REQUEST_LIMIT) {
      await sendRequest(tokenA, { email: `inconnu-${randomUUID()}@carlys.test` }).expect(202);
    }
    const blocked = await sendRequest(tokenA, {
      email: `inconnu-${randomUUID()}@carlys.test`,
    }).expect(429);
    expect(errorOf(blocked.body).code).toBe('RATE_LIMITED');

    // Le seau est propre à la route : le reste de la communauté répond.
    await authed(tokenA).get('/api/v1/community/friends').expect(200);
    await authed(tokenA).get('/api/v1/community/requests').expect(200);
  });
});
