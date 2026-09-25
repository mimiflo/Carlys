process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';
process.env.S3_ENDPOINT ??= 'http://localhost:9000';
process.env.S3_BUCKET ??= 'carlys-media';
process.env.S3_PRIVATE_BUCKET ??= 'carlys-private';
process.env.S3_ACCESS_KEY_ID ??= 'carlys-dev';
process.env.S3_SECRET_ACCESS_KEY ??= 'carlys-dev-secret';
process.env.S3_PUBLIC_BASE_URL ??= 'http://localhost:9000/carlys-media';

import { HeadObjectCommand, ListObjectsV2Command, S3Client } from '@aws-sdk/client-s3';
import { type ApiSuccessEnvelope, type AuthResult } from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { S3PrivateObjectStore } from '../src/infrastructure/storage/s3-private-object-store';

const PHOTO = readFileSync(join(__dirname, 'fixtures', 'jpeg', 'repas-exif-gps.jpg'));
const PASSWORD = 'MotDePasseSolide42';
const ENDPOINT = process.env.S3_ENDPOINT.replace(/\/+$/, '');
const PRIVATE_BUCKET = process.env.S3_PRIVATE_BUCKET;
const PUBLIC_BUCKET = process.env.S3_BUCKET;

/**
 * Photo d'un repas sur le VRAI stockage (MinIO) — tourne en CI, où MinIO et
 * les deux buckets existent (api-ci.yml). Sur un poste sans MinIO, c'est
 * `nutrition-photos.e2e-spec.ts` qui éprouve la même chaîne, stockage en
 * mémoire.
 *
 * Ce que seul ce fichier peut prouver : l'objet vit dans le bucket PRIVÉ, pas
 * dans celui des médias, et ce bucket REFUSE la lecture sans jeton — alors
 * que le bucket des médias, lui, l'accepte. C'est toute la promesse faite
 * dans docs/legal/privacy.md.
 */
describe('Photo d’un repas (e2e, MinIO réel)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let s3: S3Client;
  const emails: string[] = [];

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const server = () => request(app.getHttpServer());

  async function register(): Promise<{ token: string; userId: string }> {
    const email = `e2e-photo-minio-${randomUUID()}@carlys.test`;
    emails.push(email);
    const response = await server()
      .post('/api/v1/auth/register')
      .send({ email, password: PASSWORD, displayName: 'Photo MinIO' })
      .expect(201);
    const result = data<AuthResult>(response.body);
    return { token: result.tokens.accessToken, userId: result.user.id };
  }

  async function mealWithPhoto(token: string): Promise<{ mealId: string; storageKey: string }> {
    const mealId = randomUUID();
    await server()
      .post('/api/v1/nutrition/meals')
      .set('Authorization', `Bearer ${token}`)
      .send({ id: mealId, name: 'Salade', kcal: 320, eatenAt: new Date(Date.now() - 60_000) })
      .expect(201);
    await server()
      .put(`/api/v1/nutrition/meals/${mealId}/photo`)
      .set('Authorization', `Bearer ${token}`)
      .attach('file', PHOTO, { filename: 'IMG_0042.jpg', contentType: 'image/jpeg' })
      .expect(200);
    const { storageKey } = await prisma.mealPhoto.findUniqueOrThrow({ where: { mealId } });
    return { mealId, storageKey };
  }

  async function exists(bucket: string, key: string): Promise<boolean> {
    try {
      await s3.send(new HeadObjectCommand({ Bucket: bucket, Key: key }));
      return true;
    } catch (error) {
      if ((error as Error).name === 'NotFound') {
        return false;
      }
      throw error;
    }
  }

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    s3 = new S3Client({
      endpoint: ENDPOINT,
      region: 'us-east-1',
      forcePathStyle: true,
      credentials: {
        accessKeyId: process.env.S3_ACCESS_KEY_ID!,
        secretAccessKey: process.env.S3_SECRET_ACCESS_KEY!,
      },
    });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
    await prisma.$disconnect();
    s3.destroy();
    await app.close();
  });

  it('le bucket privé existe et ne porte AUCUNE politique d’accès', async () => {
    expect(await app.get(S3PrivateObjectStore).inspect()).toEqual({ state: 'ok' });
  });

  it('l’objet vit dans le bucket PRIVÉ, sans métadonnées, et jamais dans celui des médias', async () => {
    const { token } = await register();
    const { mealId, storageKey } = await mealWithPhoto(token);

    expect(await exists(PRIVATE_BUCKET, storageKey)).toBe(true);
    expect(await exists(PUBLIC_BUCKET, storageKey)).toBe(false);

    const response = await server()
      .get(`/api/v1/nutrition/meals/${mealId}/photo`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const body = response.body as Buffer;
    expect(body.includes(Buffer.from('Exif'))).toBe(false);
    expect(body.includes(Buffer.from('GPS'))).toBe(false);
  });

  it('sans jeton, le stockage REFUSE : ni l’objet, ni la liste des clés', async () => {
    const { token } = await register();
    const { storageKey } = await mealWithPhoto(token);

    const object = await fetch(`${ENDPOINT}/${PRIVATE_BUCKET}/${storageKey}`);
    expect(object.status).toBe(403);
    const listing = await fetch(`${ENDPOINT}/${PRIVATE_BUCKET}/?list-type=2`);
    expect(listing.status).toBe(403);
  });

  it('supprimer le repas efface l’objet du bucket', async () => {
    const { token } = await register();
    const { mealId, storageKey } = await mealWithPhoto(token);

    await server()
      .delete(`/api/v1/nutrition/meals/${mealId}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(204);

    expect(await exists(PRIVATE_BUCKET, storageKey)).toBe(false);
  });

  it('supprimer le compte vide tout son préfixe dans le bucket', async () => {
    const { token, userId } = await register();
    await mealWithPhoto(token);
    await mealWithPhoto(token);

    await server()
      .delete('/api/v1/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ password: PASSWORD })
      .expect(204);

    const left = await s3.send(
      new ListObjectsV2Command({ Bucket: PRIVATE_BUCKET, Prefix: `meal-photos/${userId}/` }),
    );
    expect(left.Contents ?? []).toEqual([]);
  });
});
