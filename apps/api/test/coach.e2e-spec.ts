process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';
process.env.ANTHROPIC_API_KEY ??= 'sk-ant-cle-factice-pour-les-tests-e2e';
process.env.COACH_ENABLED = 'true';

import {
  type ApiSuccessEnvelope,
  type AuthResult,
  type CoachConversation,
  type CoachConversationSummary,
  type CoachReply,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { Redis } from 'ioredis';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import {
  COACH_MODEL_PORT,
  type CoachModelPort,
  type CoachTurnOutput,
} from '../src/modules/coach/domain/coach-model.port';
import { ensureExerciseFixture } from './support/exercise-fixture';

/**
 * Coach IA (e2e) : le droit et le quota décident AVANT toute dépense, et
 * aucune séance inventée ne franchit la validation.
 *
 * Le fournisseur de modèle est remplacé par un faux — un test qui appellerait
 * un modèle réel serait lent, coûteux et non déterministe.
 */
describe('Coach IA (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let accessToken: string;
  let otherAccessToken: string;
  let userId: string;
  let exerciseId: string;

  const userEmail = `e2e-coach-${randomUUID()}@carlys.test`;
  const otherEmail = `e2e-coach-autre-${randomUUID()}@carlys.test`;

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

  /** Réponse que le faux modèle rendra au prochain tour. */
  let nextOutput: CoachTurnOutput;

  const textOnly = (text: string): CoachTurnOutput => ({
    text,
    proposal: null,
    usage: { inputTokens: 120, outputTokens: 40, cacheReadTokens: 0 },
    refused: false,
  });

  const fakeModel: CoachModelPort = {
    reply: async (input) => {
      // Le faux appelle un outil de lecture : on vérifie ainsi que la chaîne
      // complète fonctionne, pas seulement l'écriture en base.
      await input.runTools([{ id: 'call-1', name: 'get_personal_records', input: {} }]);
      return nextOutput;
    },
  };

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(COACH_MODEL_PORT)
      .useValue(fakeModel)
      .compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const register = (email: string) =>
      request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ email, password: 'MotDePasseSolide!2026', displayName: 'Coach e2e' })
        .expect(201);

    const first = data<AuthResult>((await register(userEmail)).body);
    accessToken = first.tokens.accessToken;
    userId = first.user.id;
    otherAccessToken = data<AuthResult>((await register(otherEmail)).body).tokens.accessToken;

    const exercise = await ensureExerciseFixture(prisma, 'e2e-coach-developpe');
    exerciseId = exercise.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: [userEmail, otherEmail] } } });
    await prisma.exercise.deleteMany({ where: { slug: 'e2e-coach-developpe' } });
    await prisma.$disconnect();
    await app.close();
  });

  const authed = (token: string) => ({
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${token}`),
  });

  /** Accorde le droit directement : les webhooks sont testés ailleurs. */
  const grantCoaching = () =>
    prisma.userEntitlement.upsert({
      where: { userId_entitlementKey: { userId, entitlementKey: 'ai_coaching' } },
      create: { userId, entitlementKey: 'ai_coaching', isActive: true },
      update: { isActive: true, expiresAt: null },
    });

  const revokeCoaching = () =>
    prisma.userEntitlement.updateMany({
      where: { userId, entitlementKey: 'ai_coaching' },
      data: { isActive: false },
    });

  const resetQuota = async () => {
    // Le quota vit dans Redis : chaque scénario repart d'un compteur propre.
    const key = `coach:quota:${userId}:${new Date().toISOString().slice(0, 10)}`;
    const client = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    await client.del(key);
    await client.quit();
  };

  it('sans le droit ai_coaching, le coach est refusé (403) avant toute dépense', async () => {
    await revokeCoaching();
    await authed(accessToken).get('/api/v1/coach/conversations').expect(403);
    await request(app.getHttpServer()).get('/api/v1/coach/conversations').expect(401);
  });

  it('avec le droit, un fil s’ouvre et le coach répond', async () => {
    await grantCoaching();
    await resetQuota();
    nextOutput = textOnly('Tu progresses régulièrement sur le développé couché.');

    const conversationId = randomUUID();
    const created = data<CoachConversationSummary>(
      (
        await authed(accessToken)
          .post('/api/v1/coach/conversations')
          .send({ id: conversationId })
          .expect(201)
      ).body,
    );
    expect(created.id).toBe(conversationId);

    const reply = data<CoachReply>(
      (
        await authed(accessToken)
          .post(`/api/v1/coach/conversations/${conversationId}/messages`)
          .send({ id: randomUUID(), content: 'Où j’en suis sur le développé ?' })
          .expect(201)
      ).body,
    );

    expect(reply.assistantMessage.content).toContain('développé couché');
    expect(reply.assistantMessage.proposal).toBeNull();
    expect(reply.remainingToday).toBeGreaterThanOrEqual(0);

    const conversation = data<CoachConversation>(
      (await authed(accessToken).get(`/api/v1/coach/conversations/${conversationId}`).expect(200))
        .body,
    );
    expect(conversation.messages).toHaveLength(2);
    // Le titre du fil vient de la première question.
    expect(conversation.title).toContain('développé');
  });

  it('une séance proposée n’existe que si chaque exercice existe', async () => {
    await grantCoaching();
    await resetQuota();
    const conversationId = randomUUID();
    await authed(accessToken)
      .post('/api/v1/coach/conversations')
      .send({ id: conversationId })
      .expect(201);

    nextOutput = {
      ...textOnly('Voici une adaptation de ta séance.'),
      proposal: {
        name: 'Haut du corps — format court',
        estimatedMinutes: 25,
        items: [
          {
            exercisePosition: 0,
            exerciseId,
            setPosition: 0,
            kind: 'NORMAL',
            targetReps: 8,
            targetWeightKg: 60,
            restSeconds: 90,
          },
        ],
      },
    };

    const reply = data<CoachReply>(
      (
        await authed(accessToken)
          .post(`/api/v1/coach/conversations/${conversationId}/messages`)
          .send({ id: randomUUID(), content: 'J’ai peu de temps aujourd’hui.' })
          .expect(201)
      ).body,
    );

    const proposal = reply.assistantMessage.proposal;
    expect(proposal).not.toBeNull();
    expect(proposal?.items).toHaveLength(1);
    // Le nom vient du catalogue, jamais du modèle.
    expect(proposal?.items[0]?.exerciseName).toBeTruthy();

    // Accepter ne crée AUCUNE séance : la séance naît par la route existante.
    await authed(accessToken)
      .post(`/api/v1/coach/proposals/${proposal!.id}/accepted`)
      .send({ sessionId: randomUUID() })
      .expect(204);
  });

  it('un exercice inventé fait tomber la proposition, pas la réponse', async () => {
    await grantCoaching();
    await resetQuota();
    const conversationId = randomUUID();
    await authed(accessToken)
      .post('/api/v1/coach/conversations')
      .send({ id: conversationId })
      .expect(201);

    nextOutput = {
      ...textOnly('Voici une adaptation de ta séance.'),
      proposal: {
        name: 'Séance impossible',
        estimatedMinutes: 30,
        items: [
          {
            exercisePosition: 0,
            // Identifiant crédible, absent du catalogue.
            exerciseId: randomUUID(),
            setPosition: 0,
            targetReps: 10,
          },
        ],
      },
    };

    const reply = data<CoachReply>(
      (
        await authed(accessToken)
          .post(`/api/v1/coach/conversations/${conversationId}/messages`)
          .send({ id: randomUUID(), content: 'Propose-moi une séance.' })
          .expect(201)
      ).body,
    );

    // L'utilisateur garde une réponse lisible ; la séance inventée, elle,
    // n'existe pas.
    expect(reply.assistantMessage.content).toBeTruthy();
    expect(reply.assistantMessage.proposal).toBeNull();
  });

  it('un fil appartient à son propriétaire, et à personne d’autre', async () => {
    await grantCoaching();
    await resetQuota();
    const conversationId = randomUUID();
    await authed(accessToken)
      .post('/api/v1/coach/conversations')
      .send({ id: conversationId })
      .expect(201);

    // L'autre compte n'a pas le droit : 403 avant même la question de propriété.
    await authed(otherAccessToken).get(`/api/v1/coach/conversations/${conversationId}`).expect(403);
  });

  it('au-delà du plafond quotidien, l’envoi est refusé (429)', async () => {
    await grantCoaching();
    await resetQuota();
    nextOutput = textOnly('D’accord.');

    const conversationId = randomUUID();
    await authed(accessToken)
      .post('/api/v1/coach/conversations')
      .send({ id: conversationId })
      .expect(201);

    const limit = Number.parseInt(process.env.COACH_DAILY_MESSAGE_LIMIT ?? '30', 10);

    for (let sent = 0; sent < limit; sent++) {
      await authed(accessToken)
        .post(`/api/v1/coach/conversations/${conversationId}/messages`)
        .send({ id: randomUUID(), content: `Message ${sent}` })
        .expect(201);
    }

    await authed(accessToken)
      .post(`/api/v1/coach/conversations/${conversationId}/messages`)
      .send({ id: randomUUID(), content: 'Un de trop.' })
      .expect(429);
  });

  it('coach coupé globalement : 503, jamais une erreur serveur', async () => {
    // L'interrupteur doit couper proprement, sans déploiement.
    await grantCoaching();
    const previous = process.env.COACH_ENABLED;
    process.env.COACH_ENABLED = 'false';

    const restarted = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(COACH_MODEL_PORT)
      .useValue(fakeModel)
      .compile();
    const disabled = restarted.createNestApplication<NestExpressApplication>();
    configureApp(disabled);
    await disabled.init();

    await request(disabled.getHttpServer())
      .get('/api/v1/coach/conversations')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(503);

    await disabled.close();
    process.env.COACH_ENABLED = previous ?? 'true';
  });
});
