process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';
// Un worker factice : `fetch` est doublé, rien ne part sur le réseau.
process.env.COACH_API_BASE_URL = 'http://vision.test/v1';
process.env.COACH_MODEL = 'modele-factice-e2e';
process.env.COACH_VISION_MODEL = 'vision-factice-e2e';
process.env.COACH_ENABLED = 'true';
process.env.COACH_MEAL_SCANS_PER_DAY = '3';

import {
  type ApiErrorEnvelope,
  type ApiSuccessEnvelope,
  type AuthResult,
  type MealScan,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { Redis } from 'ioredis';
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { importCiqualDirectory } from '../src/modules/nutrition/infrastructure/ciqual/ciqual-import';

const PHOTO = readFileSync(join(__dirname, 'fixtures', 'jpeg', 'repas-exif-gps.jpg'));
const POULET = 990001;

/**
 * Le scan d'une assiette, de bout en bout : la photo part, le modèle de
 * vision (doublé) dit ce qu'il voit, la base CIQUAL du jeu d'essai nomme
 * l'aliment, et le client relit le résultat — droits, quota et rejeu compris.
 */
describe('Nutrition : scan d’assiette par le modèle de vision (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let redis: Redis;
  let token: string;
  let userId: string;
  let otherToken: string;
  const emails = [`e2e-scan-${randomUUID()}@carlys.test`, `e2e-scan-b-${randomUUID()}@carlys.test`];
  const sent: { model: unknown; image: boolean }[] = [];
  const realFetch = globalThis.fetch;
  let answer =
    '{"aliments":[{"nom":"Poulet, filet, grillé","grammes":150},{"nom":"Sauce mystère","grammes":30}]}';

  const scan = (as: string, id: string) =>
    request(app.getHttpServer())
      .post('/api/v1/nutrition/meal-scans')
      .set('Authorization', `Bearer ${as}`)
      .field('id', id)
      .attach('file', PHOTO, { filename: 'repas.jpg', contentType: 'image/jpeg' });
  const read = (as: string, id: string) =>
    request(app.getHttpServer())
      .get(`/api/v1/nutrition/meal-scans/${id}`)
      .set('Authorization', `Bearer ${as}`);
  const data = (response: { body: unknown }) =>
    (response.body as ApiSuccessEnvelope<MealScan>).data;

  async function until(id: string): Promise<MealScan> {
    for (let i = 0; i < 50; i++) {
      const current = data(await read(token, id).expect(200));
      if (current.status !== 'PENDING') return current;
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    throw new Error('scan toujours en cours');
  }

  async function register(email: string) {
    const response = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email, password: 'MotDePasseSolide42', displayName: 'E2E' })
      .expect(201);
    return (response.body as ApiSuccessEnvelope<AuthResult>).data;
  }

  beforeAll(async () => {
    jest.spyOn(globalThis, 'fetch').mockImplementation((input, init) => {
      const url = input instanceof Request ? input.url : input.toString();
      if (!url.startsWith('http://vision.test/')) return realFetch(input, init);
      const body = JSON.parse(typeof init?.body === 'string' ? init.body : '') as {
        model: unknown;
        messages: { content: { type: string }[] }[];
      };
      sent.push({
        model: body.model,
        image: body.messages[0]?.content.some((part) => part.type === 'image_url') ?? false,
      });
      return Promise.resolve(Response.json({ choices: [{ message: { content: answer } }] }));
    });
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
    await importCiqualDirectory(prisma, join(__dirname, 'fixtures', 'ciqual', 'v1'));
    const [first, second] = await Promise.all(emails.map(register));
    token = first!.tokens.accessToken;
    userId = first!.user.id;
    otherToken = second!.tokens.accessToken;
  });

  afterAll(async () => {
    jest.restoreAllMocks();
    const keys = await redis.keys(`coach:meal-scans:${userId}:*`);
    if (keys.length > 0) await redis.del(...keys);
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
    await prisma.$disconnect();
    await redis.quit();
    await app.close();
  });

  it('sans le droit au coach : 403, la photo ne part pas', async () => {
    await scan(token, randomUUID()).expect(403);
    expect(sent).toHaveLength(0);
  });

  it('avec le droit : en cours, puis les aliments vus et leur aliment CIQUAL', async () => {
    await prisma.userEntitlement.create({
      data: { userId, entitlementKey: 'ai_coaching', isActive: true },
    });
    const id = randomUUID();
    const started = await scan(token, id).expect(202);
    expect(data(started).status).toBe('PENDING');

    const done = await until(id);
    expect(done.status).toBe('DONE');
    expect(done.items.map((item) => [item.seen, item.grams, item.food?.code ?? null])).toEqual([
      ['Poulet, filet, grillé', 150, POULET],
      ['Sauce mystère', 30, null],
    ]);
    expect(sent.at(-1)).toEqual({ model: 'vision-factice-e2e', image: true });

    // Rejoué : le même scan, sans seconde analyse.
    const before = sent.length;
    expect(data(await scan(token, id).expect(202)).status).toBe('DONE');
    expect(sent).toHaveLength(before);
  });

  it('le scan d’autrui : 404 à la lecture', async () => {
    const id = randomUUID();
    await scan(token, id).expect(202);
    await until(id);
    await read(otherToken, id).expect(404);
  });

  it('au-delà du quota du jour : 429', async () => {
    answer = '{"aliments":[]}';
    await until(data(await scan(token, randomUUID()).expect(202)).id);
    const response = await scan(token, randomUUID()).expect(429);
    expect((response.body as ApiErrorEnvelope).error.message).toContain('scans d’assiette du jour');
  });

  it('pas un JPEG : 415', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/nutrition/meal-scans')
      .set('Authorization', `Bearer ${token}`)
      .field('id', randomUUID())
      .attach('file', Buffer.from('pas une image'), { filename: 'x.png', contentType: 'image/png' })
      .expect(415);
  });
});
