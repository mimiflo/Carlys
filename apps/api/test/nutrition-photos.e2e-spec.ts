process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiErrorEnvelope,
  type ApiSuccessEnvelope,
  type AuthResult,
  MEAL_PHOTO_MAX_BYTES,
  type MealEntry,
} from '@carlys/api-contracts';
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
import { PRIVATE_OBJECT_STORE } from '../src/infrastructure/storage/private-object-store';
import { sweepOrphanMealPhotos } from '../src/modules/nutrition/application/meal-photo-sweep';
import { MealPhotoLedger } from '../src/modules/nutrition/infrastructure/meal-photo-ledger';
import { InMemoryObjectStore } from './support/in-memory-object-store';
import { reinitialiserDebit } from './support/throttle';

/** Une vraie photo de téléphone : EXIF avec position GPS, XMP, IPTC, commentaire. */
const PHOTO = readFileSync(join(__dirname, 'fixtures', 'jpeg', 'repas-exif-gps.jpg'));
/** La même, densité JFIF changée : d'autres octets stockés, donc une autre photo. */
const OTHER_PHOTO = Buffer.from(PHOTO);
OTHER_PHOTO[15] = 2;
const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);
const PASSWORD = 'MotDePasseSolide42';

/**
 * Photo d'un repas, PRIVÉE — la chaîne complète, sans MinIO.
 *
 * Le stockage privé est remplacé par un double en mémoire (`PRIVATE_OBJECT_STORE`
 * est un port) : tout le reste est réel — routes, garde JWT, multer, filtre
 * des métadonnées, PostgreSQL, suppression de compte. Le vrai bucket, et le
 * fait qu'il refuse la lecture anonyme, sont éprouvés en CI par
 * `nutrition-photos-minio.e2e-spec.ts`.
 */
describe('Photo d’un repas (e2e, stockage en mémoire)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  const store = new InMemoryObjectStore();
  const emails: string[] = [];

  const data = <T>(body: unknown): T => (body as ApiSuccessEnvelope<T>).data;
  const errorOf = (body: unknown) => (body as ApiErrorEnvelope).error;
  const server = () => request(app.getHttpServer());
  const as = (token: string) => ({
    get: (url: string) => server().get(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) => server().post(url).set('Authorization', `Bearer ${token}`),
    put: (url: string) => server().put(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) => server().delete(url).set('Authorization', `Bearer ${token}`),
  });

  async function register(): Promise<{ token: string; userId: string }> {
    const email = `e2e-photo-repas-${randomUUID()}@carlys.test`;
    emails.push(email);
    const response = await server()
      .post('/api/v1/auth/register')
      .send({ email, password: PASSWORD, displayName: 'Photo E2E' })
      .expect(201);
    const result = data<AuthResult>(response.body);
    return { token: result.tokens.accessToken, userId: result.user.id };
  }

  async function createMeal(token: string): Promise<string> {
    const id = randomUUID();
    await as(token)
      .post('/api/v1/nutrition/meals')
      .send({ id, name: 'Poulet riz', kcal: 650, eatenAt: new Date(Date.now() - 60_000) })
      .expect(201);
    return id;
  }

  const photoUrl = (mealId: string) => `/api/v1/nutrition/meals/${mealId}/photo`;
  const upload = (token: string, mealId: string, bytes = PHOTO, contentType = 'image/jpeg') =>
    as(token)
      .put(photoUrl(mealId))
      .attach('file', bytes, { filename: 'IMG_0042-chez-moi.jpg', contentType });

  let alice: { token: string; userId: string };
  let bob: { token: string; userId: string };

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PRIVATE_OBJECT_STORE)
      .useValue(store)
      .compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
    alice = await register();
    bob = await register();
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
    await prisma.$disconnect();
    await app.close();
  });

  // Cette suite dépose plus de vingt photos : sans remise à zéro entre ses
  // tests, la limite de débit de la route (qu'un test dédié PROUVE plus bas)
  // refuserait les derniers dépôts.
  beforeEach(async () => {
    store.failDeletes = false;
    await reinitialiserDebit();
  });

  it('dépose la photo SANS ses métadonnées, sous une clé qui ne doit rien au nom envoyé', async () => {
    const mealId = await createMeal(alice.token);
    expect(
      data<MealEntry>((await as(alice.token).get(`/api/v1/nutrition/meals/${mealId}`)).body).photo,
    ).toBeNull();

    const meal = data<MealEntry>((await upload(alice.token, mealId).expect(200)).body);

    expect(meal.photo?.updatedAt).toEqual(expect.any(String));
    const keys = store.keysUnder(`meal-photos/${alice.userId}/`);
    expect(keys).toHaveLength(1);
    expect(keys[0]).toMatch(/^meal-photos\/[0-9a-f-]{36}\/[0-9a-f-]{36}\.jpg$/);
    expect(keys[0]).not.toContain('IMG_0042');
    const stored = store.objects.get(keys[0]!)!.body;
    for (const trace of ['Exif', 'GPS', 'iPhone', 'Paris', 'Lilas', 'Photoshop']) {
      expect({ trace, present: stored.includes(Buffer.from(trace)) }).toEqual({
        trace,
        present: false,
      });
    }
  });

  it('relit les octets : image/jpeg, cache PRIVÉ, ETag, et 304 quand rien n’a changé', async () => {
    const mealId = await createMeal(alice.token);
    await upload(alice.token, mealId).expect(200);

    const response = await as(alice.token).get(photoUrl(mealId)).expect(200);

    expect(response.headers['content-type']).toBe('image/jpeg');
    expect(response.headers['cache-control']).toBe('private, no-cache');
    const etag = response.headers.etag as string;
    expect(etag).toMatch(/^"[0-9a-f]{64}"$/);
    const body = response.body as Buffer;
    expect(body.subarray(0, 3)).toEqual(Buffer.from([0xff, 0xd8, 0xff]));
    expect(body.includes(Buffer.from('Exif'))).toBe(false);

    await as(alice.token).get(photoUrl(mealId)).set('If-None-Match', etag).expect(304);
    // Et la liste du journal annonce la photo, pour que l'écran sache la demander.
    const day = await as(alice.token)
      .get('/api/v1/nutrition/meals')
      .query({ from: new Date(Date.now() - 3_600_000).toISOString(), to: new Date().toISOString() })
      .expect(200);
    const listed = data<MealEntry[]>(day.body).find((entry) => entry.id === mealId);
    expect(listed?.photo).not.toBeNull();
  });

  it('personne d’autre : 404 indiscernable d’un repas inconnu, pour lire, poser ou retirer', async () => {
    const mealId = await createMeal(alice.token);
    await upload(alice.token, mealId).expect(200);
    const unknown = errorOf((await as(bob.token).get(photoUrl(randomUUID())).expect(404)).body);

    for (const response of [
      await as(bob.token).get(photoUrl(mealId)).expect(404),
      await upload(bob.token, mealId).expect(404),
      await as(bob.token).delete(photoUrl(mealId)).expect(404),
    ]) {
      expect(errorOf(response.body).message).toBe(unknown.message);
    }
    await server().get(photoUrl(mealId)).expect(401);
    await server().put(photoUrl(mealId)).attach('file', PHOTO, 'a.jpg').expect(401);
    // La photo d'Alice est intacte.
    expect(store.keysUnder(`meal-photos/${alice.userId}/`).length).toBeGreaterThan(0);
    expect(store.keysUnder(`meal-photos/${bob.userId}/`)).toEqual([]);
  });

  it('le type se prouve par les OCTETS : un PNG annoncé JPEG, un JPEG annoncé PNG → 415', async () => {
    const mealId = await createMeal(alice.token);
    const objectsBefore = store.objects.size;

    const png = await upload(alice.token, mealId, PNG_1X1, 'image/jpeg').expect(415);
    expect(errorOf(png.body).code).toBe('UNSUPPORTED_MEDIA_TYPE');
    expect(errorOf(png.body).message).toContain('signature JPEG');
    await upload(alice.token, mealId, PHOTO, 'image/png').expect(415);
    await upload(alice.token, mealId, PHOTO.subarray(0, 900)).expect(415);

    // Refusé AVANT le stockage : aucun objet déposé, aucune photo annoncée.
    expect(store.objects.size).toBe(objectsBefore);
    const meal = data<MealEntry>(
      (await as(alice.token).get(`/api/v1/nutrition/meals/${mealId}`)).body,
    );
    expect(meal.photo).toBeNull();
  });

  it('au-delà de 5 Mo : 413 en français, coupé pendant la réception', async () => {
    const mealId = await createMeal(alice.token);
    const huge = Buffer.concat([PHOTO, Buffer.alloc(MEAL_PHOTO_MAX_BYTES)]);

    const response = await upload(alice.token, mealId, huge).expect(413);

    expect(errorOf(response.body)).toMatchObject({
      code: 'PAYLOAD_TOO_LARGE',
      message: 'Photo trop lourde : 5 Mo au plus.',
    });
  });

  it('forme de l’envoi : sans fichier, deux fichiers, un champ en trop → 400', async () => {
    const mealId = await createMeal(alice.token);

    await as(alice.token).put(photoUrl(mealId)).expect(400);
    await as(alice.token)
      .put(photoUrl(mealId))
      .attach('file', PHOTO, { filename: 'a.jpg', contentType: 'image/jpeg' })
      .attach('file', PHOTO, { filename: 'b.jpg', contentType: 'image/jpeg' })
      .expect(400);
    const extra = await as(alice.token)
      .put(photoUrl(mealId))
      .field('legende', 'mon dîner')
      .attach('file', PHOTO, { filename: 'a.jpg', contentType: 'image/jpeg' })
      .expect(400);
    expect(errorOf(extra.body).message).toBe('Trop de champs dans l’envoi.');
    await as(alice.token)
      .put(photoUrl(mealId))
      .attach('photo', PHOTO, { filename: 'a.jpg', contentType: 'image/jpeg' })
      .expect(400);
  });

  it('remplacer : l’ancien objet est effacé, `updatedAt` change ; rejouer ne change rien', async () => {
    const mealId = await createMeal(alice.token);
    const first = data<MealEntry>((await upload(alice.token, mealId).expect(200)).body);
    const before = store.keysUnder(`meal-photos/${alice.userId}/`);

    const second = data<MealEntry>(
      (await upload(alice.token, mealId, OTHER_PHOTO).expect(200)).body,
    );

    expect(second.photo?.updatedAt).not.toBe(first.photo?.updatedAt);
    const after = store.keysUnder(`meal-photos/${alice.userId}/`);
    expect(after).toHaveLength(before.length);
    const row = await prisma.mealPhoto.findUniqueOrThrow({ where: { mealId } });
    expect(after).toContain(row.storageKey);
    expect(before).not.toContain(row.storageKey);

    const replay = data<MealEntry>(
      (await upload(alice.token, mealId, OTHER_PHOTO).expect(200)).body,
    );
    expect(replay.photo?.updatedAt).toBe(second.photo?.updatedAt);
  });

  it('retirer la photo : 204, l’objet part ; retirer encore : 204', async () => {
    const mealId = await createMeal(alice.token);
    await upload(alice.token, mealId).expect(200);
    const { storageKey } = await prisma.mealPhoto.findUniqueOrThrow({ where: { mealId } });

    await as(alice.token).delete(photoUrl(mealId)).expect(204);
    await as(alice.token).delete(photoUrl(mealId)).expect(204);

    expect(store.objects.has(storageKey)).toBe(false);
    await as(alice.token).get(photoUrl(mealId)).expect(404);
    const meal = data<MealEntry>(
      (await as(alice.token).get(`/api/v1/nutrition/meals/${mealId}`)).body,
    );
    expect(meal.photo).toBeNull();
  });

  it('supprimer le repas efface sa photo', async () => {
    const mealId = await createMeal(alice.token);
    await upload(alice.token, mealId).expect(200);
    const { storageKey } = await prisma.mealPhoto.findUniqueOrThrow({ where: { mealId } });

    await as(alice.token).delete(`/api/v1/nutrition/meals/${mealId}`).expect(204);

    expect(store.objects.has(storageKey)).toBe(false);
    expect(await prisma.mealPhoto.count({ where: { mealId } })).toBe(0);
    await as(alice.token).get(photoUrl(mealId)).expect(404);
  });

  it('stockage en panne à la suppression : 204 quand même, puis le balayage reprend l’orphelin', async () => {
    const mealId = await createMeal(alice.token);
    await upload(alice.token, mealId).expect(200);
    const { storageKey } = await prisma.mealPhoto.findUniqueOrThrow({ where: { mealId } });
    store.failDeletes = true;

    await as(alice.token).delete(`/api/v1/nutrition/meals/${mealId}`).expect(204);

    // L'objet reste, mais plus aucune ligne ne le cite : c'est un orphelin.
    expect(store.objects.has(storageKey)).toBe(true);
    expect(await prisma.mealPhoto.count({ where: { mealId } })).toBe(0);

    store.failDeletes = false;
    const report = await sweepOrphanMealPhotos(store, new MealPhotoLedger(prisma), {
      now: new Date(Date.now() + 60_000),
      graceMs: 0,
      dryRun: false,
    });
    expect(report.failures).toEqual([]);
    expect(store.objects.has(storageKey)).toBe(false);
    // Les photos vivantes, elles, sont intactes.
    const live = await prisma.mealPhoto.findMany({ where: { meal: { userId: alice.userId } } });
    for (const photo of live) {
      expect(store.objects.has(photo.storageKey)).toBe(true);
    }
  });

  it('supprimer le COMPTE efface toutes ses photos de repas, orphelins compris', async () => {
    const carol = await register();
    const meals = [await createMeal(carol.token), await createMeal(carol.token)];
    for (const mealId of meals) {
      await upload(carol.token, mealId).expect(200);
    }
    // Un orphelin : un dépôt dont la ligne n'a jamais été écrite.
    await store.put(`meal-photos/${carol.userId}/${randomUUID()}.jpg`, PHOTO, 'image/jpeg');
    expect(store.keysUnder(`meal-photos/${carol.userId}/`)).toHaveLength(3);

    await as(carol.token).delete('/api/v1/users/me').send({ password: PASSWORD }).expect(204);

    expect(store.keysUnder(`meal-photos/${carol.userId}/`)).toEqual([]);
    expect(await prisma.mealPhoto.count({ where: { mealId: { in: meals } } })).toBe(0);
    // Les repas restent (historique anonyme) ; leurs photos, non.
    expect(await prisma.mealEntry.count({ where: { id: { in: meals } } })).toBe(2);
    // Les photos des autres comptes ne sont pas touchées.
    expect(store.keysUnder(`meal-photos/${alice.userId}/`).length).toBeGreaterThan(0);
  });

  describe('dépôt croisant une suppression', () => {
    /**
     * Retient le prochain dépôt PENDANT son écriture dans le stockage : le
     * repas a déjà été lu vivant, sa ligne `MealPhoto` n'est pas encore
     * écrite. C'est la fenêtre où une suppression peut passer.
     */
    function holdNextPut(): { reached: Promise<void>; release: () => void } {
      let reach!: () => void;
      const reached = new Promise<void>((resolve) => (reach = resolve));
      let release!: () => void;
      const released = new Promise<void>((resolve) => (release = resolve));
      store.beforePut = async () => {
        store.beforePut = null;
        reach();
        await released;
      };
      return { reached, release };
    }

    afterEach(() => {
      store.beforePut = null;
    });

    it('repas supprimé pendant le dépôt : 404, et ni ligne ni objet ne restent', async () => {
      const mealId = await createMeal(alice.token);
      const prefix = `meal-photos/${alice.userId}/`;
      const before = new Set(store.keysUnder(prefix));
      const hold = holdNextPut();

      const uploading = upload(alice.token, mealId).then((response) => response);
      await hold.reached;
      await as(alice.token).delete(`/api/v1/nutrition/meals/${mealId}`).expect(204);
      hold.release();

      expect((await uploading).status).toBe(404);
      expect(await prisma.mealPhoto.count({ where: { mealId } })).toBe(0);
      expect(store.keysUnder(prefix).filter((key) => !before.has(key))).toEqual([]);
    });

    it('compte supprimé pendant le dépôt : 404, et plus aucune photo du compte nulle part', async () => {
      const dave = await register();
      const mealId = await createMeal(dave.token);
      const hold = holdNextPut();

      const uploading = upload(dave.token, mealId).then((response) => response);
      await hold.reached;
      await as(dave.token).delete('/api/v1/users/me').send({ password: PASSWORD }).expect(204);
      // La garde avait laissé passer le dépôt AVANT la suppression ; une
      // requête neuve, elle, est refusée.
      await as(dave.token).get(`/api/v1/nutrition/meals/${mealId}`).expect(401);
      hold.release();

      expect((await uploading).status).toBe(404);
      expect(await prisma.mealPhoto.count({ where: { mealId } })).toBe(0);
      expect(store.keysUnder(`meal-photos/${dave.userId}/`)).toEqual([]);
    });

    it('le balayage tient pour orphelines les photos restées sous un compte supprimé', async () => {
      const erin = await register();
      const mealId = await createMeal(erin.token);
      await upload(erin.token, mealId).expect(200);
      const { storageKey } = await prisma.mealPhoto.findUniqueOrThrow({ where: { mealId } });
      // L'état qu'aucun chemin de l'API ne doit plus produire — une ligne
      // survivant à la suppression du compte — posé à la main : le filet
      // doit le rattraper quand même.
      await prisma.user.update({
        where: { id: erin.userId },
        data: { status: 'DELETED', deletedAt: new Date() },
      });

      const report = await sweepOrphanMealPhotos(store, new MealPhotoLedger(prisma), {
        now: new Date(Date.now() + 60_000),
        graceMs: 0,
        dryRun: false,
      });

      expect(report.failures).toEqual([]);
      expect(store.objects.has(storageKey)).toBe(false);
      expect(await prisma.mealPhoto.count({ where: { mealId } })).toBe(0);
    });
  });

  it('limite de débit : au-delà de vingt dépôts par minute, 429', async () => {
    await reinitialiserDebit();
    const statuses: number[] = [];
    for (let index = 0; index < 21; index += 1) {
      // Un repas inconnu : la limite compte l'appel avant toute lecture.
      statuses.push((await upload(alice.token, randomUUID())).status);
    }
    expect(statuses.slice(0, 20).every((status) => status === 404)).toBe(true);
    expect(statuses[20]).toBe(429);
    await reinitialiserDebit();
  });
});
