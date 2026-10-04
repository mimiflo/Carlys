process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiErrorEnvelope,
  type ApiSuccessEnvelope,
  type AuthResult,
  type PackagedFood,
  type PackagedFoodMeta,
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

/**
 * Un produit par son code-barres : l'API interroge Open Food Facts — ici une
 * doublure de `fetch`, jamais le réseau —, garde la réponse, et ne laisse
 * passer qu'un code valide.
 */
describe('Nutrition : produits par code-barres (e2e)', () => {
  const FOUND = '3017620422003';
  const UNKNOWN = '4006381333931';
  const DOWN = '5449000000996';
  const codes = [FOUND, UNKNOWN, DOWN, '3274080005003'];

  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let redis: Redis;
  let token: string;
  const email = `e2e-produits-${randomUUID()}@carlys.test`;
  const calls: string[] = [];
  const realFetch = globalThis.fetch;

  const get = (url: string) =>
    request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${token}`);

  beforeAll(async () => {
    jest.spyOn(globalThis, 'fetch').mockImplementation((input, init) => {
      const url = input instanceof Request ? input.url : input.toString();
      if (!url.startsWith('https://world.openfoodfacts.org/')) return realFetch(input, init);
      calls.push(url);
      if (url.includes(DOWN)) return Promise.resolve(new Response('', { status: 502 }));
      if (url.includes(UNKNOWN)) {
        return Promise.resolve(Response.json({ status: 0 }, { status: 404 }));
      }
      return Promise.resolve(
        Response.json({
          status: 1,
          product: {
            product_name_fr: 'Pâte à tartiner',
            brands: 'Nutella, Ferrero',
            serving_quantity: 15,
            nutriments: { 'energy-kcal_100g': 539, proteins_100g: 6.3, fat_100g: 30.9 },
          },
        }),
      );
    });

    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    await redis.del(
      'nutrition:product:pause',
      ...codes.map((code) => `nutrition:product:v1:${code}`),
    );
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    const response = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email, password: 'MotDePasseSolide42', displayName: 'E2E' })
      .expect(201);
    token = (response.body as ApiSuccessEnvelope<AuthResult>).data.tokens.accessToken;
  });

  afterAll(async () => {
    jest.restoreAllMocks();
    await redis.del(...codes.map((code) => `nutrition:product:v1:${code}`));
    await prisma.user.deleteMany({ where: { email } });
    await prisma.$disconnect();
    await redis.quit();
    await app.close();
  });

  it('trouvé : les valeurs pour 100 g et la mention ODbL ; le second scan lit le cache', async () => {
    const first = await get(`/api/v1/nutrition/products/${FOUND}`).expect(200);
    const envelope = first.body as ApiSuccessEnvelope<PackagedFood, PackagedFoodMeta>;
    expect(envelope.data).toEqual({
      barcode: FOUND,
      name: 'Pâte à tartiner',
      brand: 'Nutella',
      per100g: { kcal: 539, proteinG: 6.3, carbsG: null, fatG: 30.9 },
      liquid: false,
      servingQuantity: 15,
    });
    expect(envelope.meta.source.license).toContain('ODbL');
    // Seuls les champs utiles sont demandés, et l'application se nomme.
    expect(calls.at(-1)).toContain('fields=');

    await get(`/api/v1/nutrition/products/${FOUND}`).expect(200);
    expect(calls.filter((url) => url.includes(FOUND))).toHaveLength(1);
  });

  it('inconnu : 404, et l’inconnu aussi se garde', async () => {
    const response = await get(`/api/v1/nutrition/products/${UNKNOWN}`).expect(404);
    expect((response.body as ApiErrorEnvelope).error.code).toBe('NOT_FOUND');
    await get(`/api/v1/nutrition/products/${UNKNOWN}`).expect(404);
    expect(calls.filter((url) => url.includes(UNKNOWN))).toHaveLength(1);
  });

  it('la base qui ne répond pas : 503 avec un message pour la personne, puis une pause', async () => {
    const response = await get(`/api/v1/nutrition/products/${DOWN}`).expect(503);
    expect((response.body as ApiErrorEnvelope).error.message).toContain('saisis le repas');
    // Pendant la pause, même un code jamais vu n'appelle pas la base.
    const before = calls.length;
    const busy = await get('/api/v1/nutrition/products/3274080005003').expect(503);
    expect((busy.body as ApiErrorEnvelope).error.code).toBe('SERVICE_BUSY');
    expect(calls).toHaveLength(before);
    await redis.del('nutrition:product:pause');
  });

  it('un code au contrôle faux ne part pas chez le tiers : 400', async () => {
    const before = calls.length;
    await get('/api/v1/nutrition/products/3017620422004').expect(400);
    await get('/api/v1/nutrition/products/pas-un-code').expect(400);
    expect(calls).toHaveLength(before);
  });

  it('sans session : 401', async () => {
    await request(app.getHttpServer()).get(`/api/v1/nutrition/products/${FOUND}`).expect(401);
  });
});
