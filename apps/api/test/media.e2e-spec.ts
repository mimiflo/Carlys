process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';
process.env.S3_ENDPOINT ??= 'http://localhost:9000';
process.env.S3_BUCKET ??= 'carlys-media';
process.env.S3_ACCESS_KEY_ID ??= 'carlys-dev';
process.env.S3_SECRET_ACCESS_KEY ??= 'carlys-dev-secret';
process.env.S3_PUBLIC_BASE_URL ??= 'http://localhost:9000/carlys-media';

import {
  ADMIN_PERMISSIONS,
  type AdminLoginResult,
  type ApiSuccessEnvelope,
  type AuthResult,
  type ExerciseDetail,
  type MediaAsset,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { ensureExerciseFixture } from './support/exercise-fixture';

const ADMIN_PASSWORD = 'MotDePasseAdmin42!';

/** PNG 1×1 valide : de vrais octets, pas un tampon rempli de zéros. */
const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);

/**
 * Médias — **tout fichier servi par l'application entre par l'administration**.
 *
 * La suite vérifie la chaîne complète : dépôt admin → stockage objet → URL
 * publique → fiche d'exercice côté mobile. Rien n'est embarqué dans
 * l'application, donc rien ici ne doit dépendre d'un asset local.
 */
describe('Médias (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let mediaToken: string;
  let readOnlyToken: string;
  let memberToken: string;
  let exerciseId: string;
  let exerciseSlug: string;
  const mediaEmail = `e2e-media-admin-${randomUUID()}@carlys.test`;
  const readOnlyEmail = `e2e-media-lecteur-${randomUUID()}@carlys.test`;
  const memberEmail = `e2e-media-membre-${randomUUID()}@carlys.test`;
  const imageId = randomUUID();
  const meshId = randomUUID();

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;

  const server = () => request(app.getHttpServer());
  const asAdmin = (token: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) => server().post(url).set('Authorization', `Bearer ${token}`),
    put: (url: string) => server().put(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${token}`),
  });

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    // RBAC : upserts idempotents, comme le seed (la suite reste autonome).
    for (const permission of ADMIN_PERMISSIONS) {
      const [resource, action] = permission.split(':') as [string, string];
      await prisma.adminPermission.upsert({
        where: { resource_action: { resource, action } },
        update: {},
        create: { resource, action },
      });
    }
    const permissions = await prisma.adminPermission.findMany();
    const roleOf = async (slug: string, name: string, keys: readonly string[]) => {
      const role = await prisma.adminRole.upsert({
        where: { slug },
        update: {},
        create: { slug, name },
      });
      await prisma.adminRolePermission.deleteMany({ where: { roleId: role.id } });
      await prisma.adminRolePermission.createMany({
        data: permissions
          .filter((permission) => keys.includes(`${permission.resource}:${permission.action}`))
          .map((permission) => ({ roleId: role.id, permissionId: permission.id })),
      });
      return role;
    };
    const mediaRole = await roleOf('e2e-media-editeur', 'Éditeur de médias', [
      'media:read',
      'media:write',
      'exercise:write',
    ]);
    const readOnlyRole = await roleOf('e2e-media-lecteur', 'Lecteur de médias', ['media:read']);

    const passwordHash = await argon2.hash(ADMIN_PASSWORD, { type: argon2.argon2id });
    for (const [email, role] of [
      [mediaEmail, mediaRole],
      [readOnlyEmail, readOnlyRole],
    ] as const) {
      const admin = await prisma.adminUser.create({
        data: { email, displayName: 'Admin médias E2E', passwordHash },
      });
      await prisma.adminUserRole.create({ data: { adminUserId: admin.id, roleId: role.id } });
    }

    const login = async (email: string) =>
      data<AdminLoginResult>(
        (
          await server()
            .post('/api/v1/admin/auth/login')
            .send({ email, password: ADMIN_PASSWORD })
            .expect(200)
        ).body,
      ).accessToken;
    mediaToken = await login(mediaEmail);
    readOnlyToken = await login(readOnlyEmail);

    memberToken = data<AuthResult>(
      (
        await server()
          .post('/api/v1/auth/register')
          .send({ email: memberEmail, password: 'MotDePasseSolide42', displayName: 'Membre E2E' })
          .expect(201)
      ).body,
    ).tokens.accessToken;

    const exercise = await ensureExerciseFixture(prisma, 'e2e-media-illustre');
    exerciseId = exercise.id;
    exerciseSlug = exercise.slug;
  });

  afterAll(async () => {
    await prisma.exercise.deleteMany({ where: { slug: 'e2e-media-illustre' } });
    await prisma.mediaAsset.deleteMany({ where: { id: { in: [imageId, meshId] } } });
    await prisma.adminUser.deleteMany({ where: { email: { in: [mediaEmail, readOnlyEmail] } } });
    await prisma.adminRole.deleteMany({
      where: { slug: { in: ['e2e-media-editeur', 'e2e-media-lecteur'] } },
    });
    await prisma.user.deleteMany({ where: { email: memberEmail } });
    await prisma.$disconnect();
    await app.close();
  });

  it('dépôt d’une photo : objet stocké, dimensions lues, URL publique servie', async () => {
    const asset = data<MediaAsset>(
      (
        await asAdmin(mediaToken)
          .post('/api/v1/admin/media')
          .field('id', imageId)
          .field('kind', 'IMAGE')
          .attach('file', PNG_1X1, { filename: 'photo.png', contentType: 'image/png' })
          .expect(201)
      ).body,
    );

    expect(asset.id).toBe(imageId);
    // La clé vient de l'identifiant, jamais du nom déposé.
    expect(asset.url).toContain(`image/${imageId}.png`);
    expect(asset).toMatchObject({ kind: 'IMAGE', width: 1, height: 1, mimeType: 'image/png' });
  });

  it('l’URL servie est réellement lisible sans jeton (le mobile la charge telle quelle)', async () => {
    const stored = await prisma.mediaAsset.findUniqueOrThrow({ where: { id: imageId } });
    const url = `${process.env.S3_PUBLIC_BASE_URL}/${stored.storageKey}`;

    const response = await fetch(url);

    expect(response.status).toBe(200);
    expect(Buffer.from(await response.arrayBuffer())).toEqual(PNG_1X1);
  });

  it('dépôt rejoué avec le même identifiant : un seul média, pas de doublon', async () => {
    const asset = data<MediaAsset>(
      (
        await asAdmin(mediaToken)
          .post('/api/v1/admin/media')
          .field('id', imageId)
          .field('kind', 'IMAGE')
          .attach('file', PNG_1X1, { filename: 'photo.png', contentType: 'image/png' })
          .expect(201)
      ).body,
    );

    expect(asset.id).toBe(imageId);
    expect(await prisma.mediaAsset.count({ where: { id: imageId } })).toBe(1);
  });

  it('type MIME hors du genre annoncé : refusé', async () => {
    await asAdmin(mediaToken)
      .post('/api/v1/admin/media')
      .field('id', randomUUID())
      .field('kind', 'MESH_3D')
      .attach('file', PNG_1X1, { filename: 'faux.glb', contentType: 'image/png' })
      .expect(415);
  });

  it('RBAC : lire les médias ne donne pas le droit d’en déposer', async () => {
    await asAdmin(readOnlyToken).get('/api/v1/admin/media?kind=IMAGE').expect(200);
    await asAdmin(readOnlyToken)
      .post('/api/v1/admin/media')
      .field('id', randomUUID())
      .field('kind', 'IMAGE')
      .attach('file', PNG_1X1, { filename: 'photo.png', contentType: 'image/png' })
      .expect(403);
    // Un jeton mobile n'ouvre aucune porte côté administration.
    await server()
      .get('/api/v1/admin/media')
      .set('Authorization', `Bearer ${memberToken}`)
      .expect(401);
  });

  it('rattachement : la fiche mobile expose l’URL de la photo', async () => {
    await asAdmin(mediaToken)
      .put(`/api/v1/admin/exercises/${exerciseId}/image`)
      .send({ mediaId: imageId })
      .expect(204);

    const detail = data<ExerciseDetail>(
      (
        await server()
          .get(`/api/v1/exercises/${exerciseSlug}`)
          .set('Authorization', `Bearer ${memberToken}`)
          .expect(200)
      ).body,
    );
    expect(detail.imageUrl).toContain(`image/${imageId}.png`);
    expect(detail.meshUrl).toBeNull();
  });

  it('une photo ne peut pas tenir lieu de maillage 3D', async () => {
    await asAdmin(mediaToken)
      .put(`/api/v1/admin/exercises/${exerciseId}/mesh`)
      .send({ mediaId: imageId })
      .expect(400);
  });

  it('suppression refusée tant qu’un exercice référence le média', async () => {
    await asAdmin(mediaToken).delete(`/api/v1/admin/media/${imageId}`).expect(400);
    expect(
      (await prisma.mediaAsset.findUniqueOrThrow({ where: { id: imageId } })).deletedAt,
    ).toBeNull();
  });

  it('détachée puis supprimée : la fiche mobile retombe sur son repli', async () => {
    await asAdmin(mediaToken)
      .put(`/api/v1/admin/exercises/${exerciseId}/image`)
      .send({ mediaId: null })
      .expect(204);
    await asAdmin(mediaToken).delete(`/api/v1/admin/media/${imageId}`).expect(204);

    const detail = data<ExerciseDetail>(
      (
        await server()
          .get(`/api/v1/exercises/${exerciseSlug}`)
          .set('Authorization', `Bearer ${memberToken}`)
          .expect(200)
      ).body,
    );
    expect(detail.imageUrl).toBeNull();
    // Suppression LOGIQUE : la ligne reste, invisible de la bibliothèque.
    const rows = data<MediaAsset[]>(
      (await asAdmin(mediaToken).get('/api/v1/admin/media').expect(200)).body,
    );
    expect(rows.some((row) => row.id === imageId)).toBe(false);
  });
});
