process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiErrorEnvelope,
  type ApiSuccessEnvelope,
  type AuthResult,
  type MealEntry,
  type MealMeta,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { join } from 'node:path';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { importCiqualDirectory } from '../src/modules/nutrition/infrastructure/ciqual/ciqual-import';

/**
 * Corriger un repas composé : ce que la correction garde, ce qu'elle relit,
 * et ce qui se passe quand deux corrections se croisent.
 *
 * - les lignes gardent leur identifiant (UUID de l'appareil) et, désignées
 *   par lui, leur INSTANTANÉ — même quand l'aliment a quitté la base ;
 * - la mention de source et la version accompagnent les valeurs CIQUAL ;
 * - une correction se décide sur l'état lu SOUS VERROU, jamais sur une
 *   lecture faite avant qu'une autre écriture ne passe ;
 * - l'ancien client, qui renvoie toutes les clés, peut encore renommer.
 */
const FIXTURES = join(__dirname, 'fixtures', 'ciqual');
const POULET = 990001;
const RIZ = 990002;
const BROCOLI = 990003;
const CUISSE = 990008;
const ATTRIBUTION = {
  attribution: 'Source : Anses, Table de composition nutritionnelle des aliments Ciqual',
  license: 'Licence Ouverte Etalab 2.0',
  url: 'https://ciqual.anses.fr/',
};

interface Line {
  id: string;
  foodCode: number;
  quantityG: number;
}

/** Une ligne neuve : son identifiant naît sur l'appareil. */
const line = (foodCode: number, quantityG: number): Line => ({
  id: randomUUID(),
  foodCode,
  quantityG,
});

describe('Nutrition : corriger un repas (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let token: string;
  const email = `e2e-corrections-${randomUUID()}@carlys.test`;

  const data = <T>(response: { body: unknown }): T => (response.body as ApiSuccessEnvelope<T>).data;
  const metaOf = (response: { body: unknown }): MealMeta =>
    (response.body as ApiSuccessEnvelope<unknown, MealMeta>).meta;
  const errorOf = (response: { body: unknown }): string =>
    (response.body as ApiErrorEnvelope).error.message;
  const authed = () => ({
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${token}`),
    patch: (url: string) =>
      request(app.getHttpServer()).patch(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${token}`),
  });
  const mealUrl = (id: string) => `/api/v1/nutrition/meals/${id}`;

  async function createMeal(body: object): Promise<MealEntry> {
    const response = await authed()
      .post('/api/v1/nutrition/meals')
      .send({ id: randomUUID(), name: 'Repas', eatenAt: new Date().toISOString(), ...body })
      .expect(201);
    return data<MealEntry>(response);
  }

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();
    await importCiqualDirectory(prisma, join(FIXTURES, 'v1'));
    const response = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email, password: 'MotDePasseSolide42', displayName: 'E2E' })
      .expect(201);
    token = data<AuthResult>(response).tokens.accessToken;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email } });
    await prisma.$disconnect();
    await app.close();
  });

  describe('identifiants des lignes', () => {
    it('l’identifiant d’une ligne vient de l’appareil, et survit aux corrections', async () => {
      const poulet = line(POULET, 120);
      const riz = line(RIZ, 150);
      const meal = await createMeal({ components: [poulet, riz] });
      expect(meal.components.map((component) => component.id)).toEqual([poulet.id, riz.id]);

      const corrected = data<MealEntry>(
        await authed()
          .patch(mealUrl(meal.id))
          .send({ components: [{ ...riz, quantityG: 100 }, poulet] })
          .expect(200),
      );
      // Réordonnées, une quantité changée : les MÊMES lignes.
      expect(corrected.components.map((component) => [component.id, component.quantityG])).toEqual([
        [riz.id, 100],
        [poulet.id, 120],
      ]);
    });

    it('refuse une ligne sans identifiant, deux lignes au même identifiant, un aliment changé sous le même', async () => {
      const riz = line(RIZ, 100);
      await authed()
        .post('/api/v1/nutrition/meals')
        .send({
          id: randomUUID(),
          name: 'Sans id',
          eatenAt: new Date().toISOString(),
          components: [{ foodCode: RIZ, quantityG: 100 }],
        })
        .expect(400);
      await authed()
        .post('/api/v1/nutrition/meals')
        .send({
          id: randomUUID(),
          name: 'Doublon',
          eatenAt: new Date().toISOString(),
          components: [riz, { ...riz, quantityG: 50 }],
        })
        .expect(400);

      const meal = await createMeal({ components: [riz] });
      const swapped = await authed()
        .patch(mealUrl(meal.id))
        .send({ components: [{ ...riz, foodCode: POULET }] })
        .expect(400);
      expect(errorOf(swapped)).toContain(riz.id);
    });

    it('un identifiant de ligne déjà pris par un autre repas : 409, rien d’écrit', async () => {
      const taken = line(RIZ, 100);
      await createMeal({ components: [taken] });

      const created = await authed()
        .post('/api/v1/nutrition/meals')
        .send({
          id: randomUUID(),
          name: 'Copie',
          eatenAt: new Date().toISOString(),
          components: [taken],
        })
        .expect(409);
      expect(errorOf(created)).toMatch(/identifiant/i);

      const other = await createMeal({ components: [line(POULET, 100)] });
      await authed()
        .patch(mealUrl(other.id))
        .send({ components: [taken] })
        .expect(409);
      const unchanged = data<MealEntry>(await authed().get(mealUrl(other.id)).expect(200));
      expect(unchanged.components.map((component) => component.foodCode)).toEqual([POULET]);
    });
  });

  describe('mention de source', () => {
    it('les routes de repas citent la source, et chaque ligne sa version', async () => {
      const meal = await createMeal({ components: [line(POULET, 120)] });

      const read = await authed().get(mealUrl(meal.id)).expect(200);
      expect(metaOf(read)).toEqual({ source: ATTRIBUTION });
      expect(data<MealEntry>(read).components[0]?.sourceVersion).toBe('2020-07-07');

      const from = new Date(Date.now() - 3_600_000).toISOString();
      const to = new Date(Date.now() + 3_600_000).toISOString();
      const listed = await authed()
        .get(`/api/v1/nutrition/meals?from=${from}&to=${to}`)
        .expect(200);
      expect(metaOf(listed)).toEqual({ source: ATTRIBUTION });

      // Un repas saisi à la main ne montre aucune valeur de la table.
      const manual = await createMeal({ kcal: 300 });
      expect(metaOf(await authed().get(mealUrl(manual.id)).expect(200))).toEqual({});
    });
  });

  describe('client déjà publié', () => {
    it('renvoyer les totaux INCHANGÉS d’un repas composé n’est pas une correction', async () => {
      const meal = await createMeal({ components: [line(POULET, 120), line(RIZ, 150)] });
      // Ce que l'écran de correction actuel envoie : toutes les clés, telles
      // qu'il les a lues.
      const everything = {
        name: 'Renommé ailleurs',
        kcal: meal.kcal,
        quantity: meal.quantity,
        quantityUnit: meal.quantityUnit,
        proteinG: meal.proteinG,
        carbsG: meal.carbsG,
        fatG: meal.fatG,
        eatenAt: meal.eatenAt,
      };

      const renamed = data<MealEntry>(
        await authed().patch(mealUrl(meal.id)).send(everything).expect(200),
      );
      expect(renamed).toMatchObject({ name: 'Renommé ailleurs', kcal: meal.kcal, computed: true });
      expect(renamed.components).toHaveLength(2);

      // Une valeur CHANGÉE reste refusée : elle ne correspondrait plus aux aliments.
      const changed = await authed()
        .patch(mealUrl(meal.id))
        .send({ ...everything, kcal: meal.kcal + 1 })
        .expect(400);
      expect(errorOf(changed)).toMatch(/kcal/);
    });
  });

  describe('corrections simultanées', () => {
    /**
     * Attend qu'une requête de l'API soit BLOQUÉE sur le verrou d'une ligne
     * de repas : c'est l'instant où elle a lu, ou voudrait lire, l'état que
     * l'écriture concurrente est en train de changer.
     */
    async function untilBlockedOnMeal(): Promise<void> {
      for (let attempt = 0; attempt < 250; attempt += 1) {
        const [row] = await prisma.$queryRaw<{ waiting: number }[]>`
          SELECT count(*)::int AS waiting FROM pg_stat_activity
          WHERE datname = current_database() AND wait_event_type = 'Lock'
            AND query LIKE '%MealEntry%'`;
        if ((row?.waiting ?? 0) > 0) {
          return;
        }
        await new Promise((resolve) => setTimeout(resolve, 20));
      }
      throw new Error('Aucune requête n’a attendu le verrou du repas.');
    }

    /**
     * Une RECOMPOSITION concurrente, retenue le temps qu'une correction
     * arrive : la ligne du repas est verrouillée, puis la composition et ses
     * totaux sont écrits et validés pendant que la correction attend.
     */
    async function whileRecomposing(mealId: string, correction: () => Promise<unknown>) {
      const [poulet, riz] = await Promise.all([
        prisma.food.findUniqueOrThrow({ where: { code: POULET } }),
        prisma.food.findUniqueOrThrow({ where: { code: RIZ } }),
      ]);
      let locked!: () => void;
      const isLocked = new Promise<void>((resolve) => (locked = resolve));
      let release!: () => void;
      const released = new Promise<void>((resolve) => (release = resolve));
      const recomposition = prisma.$transaction(
        async (tx) => {
          await tx.$queryRaw`SELECT 1 FROM "MealEntry" WHERE "id" = ${mealId}::uuid FOR UPDATE`;
          locked();
          await released;
          await tx.mealComponent.createMany({
            data: [poulet, riz].map((food, position) => ({
              id: randomUUID(),
              mealId,
              position,
              foodCode: food.code,
              quantityG: 100,
              foodName: food.name,
              foodShortName: food.shortName,
              foodGroup: food.groupName,
              foodSourceVersion: food.sourceVersion,
              kcalPer100g: food.kcalPer100g,
              proteinPer100g: food.proteinPer100g,
              carbsPer100g: food.carbsPer100g,
              fatPer100g: food.fatPer100g,
            })),
          });
          // 150 + 130 kcal pour 100 g de chaque.
          await tx.mealEntry.update({
            where: { id: mealId },
            data: { kcal: 280, quantity: 200, quantityUnit: 'GRAM' },
          });
        },
        { timeout: 20_000 },
      );
      await isLocked;
      const pending = correction();
      await untilBlockedOnMeal();
      release();
      await recomposition;
      return pending;
    }

    /** L'invariant d'un repas composé : son total EST la somme de ses aliments. */
    async function expectConsistent(mealId: string): Promise<MealEntry> {
      const meal = data<MealEntry>(await authed().get(mealUrl(mealId)).expect(200));
      if (meal.computed) {
        const sum = meal.components.reduce((total, component) => total + component.kcal, 0);
        expect(meal.kcal).toBe(Math.round(sum));
      }
      return meal;
    }

    it('une correction manuelle croisant une recomposition est refusée, pas écrite par-dessus', async () => {
      const meal = await createMeal({ kcal: 300 });

      const response = (await whileRecomposing(meal.id, () =>
        authed()
          .patch(mealUrl(meal.id))
          .send({ kcal: 500 })
          .then((result) => result),
      )) as request.Response;

      expect(response.status).toBe(400);
      expect(errorOf(response)).toMatch(/retire d’abord sa composition/);
      expect(await expectConsistent(meal.id)).toMatchObject({ kcal: 280, computed: true });
    });

    it('retirer la composition en croisant une recomposition retire aussi la nouvelle', async () => {
      const meal = await createMeal({ kcal: 300 });

      const response = (await whileRecomposing(meal.id, () =>
        authed()
          .patch(mealUrl(meal.id))
          .send({ components: [], kcal: 500 })
          .then((result) => result),
      )) as request.Response;

      expect(response.status).toBe(200);
      expect(await expectConsistent(meal.id)).toMatchObject({
        kcal: 500,
        computed: false,
        components: [],
      });
    });
  });

  describe('nouvelle version de la table', () => {
    it('une ligne désignée par son identifiant garde son instantané, même d’un aliment retiré', async () => {
      const cuisse = line(CUISSE, 100);
      const brocoli = line(BROCOLI, 50);
      const before = await createMeal({ components: [cuisse, brocoli] });

      // La v2 retire la cuisse et passe le brocoli de 29,5 à 30,5 kcal/100 g.
      await importCiqualDirectory(prisma, join(FIXTURES, 'v2'));

      // « Modifier ce repas » : le brocoli passe à 80 g, la cuisse reste.
      const corrected = data<MealEntry>(
        await authed()
          .patch(mealUrl(before.id))
          .send({ components: [cuisse, { ...brocoli, quantityG: 80 }] })
          .expect(200),
      );
      expect(corrected.components[0]).toEqual({
        ...before.components[0],
        sourceVersion: '2020-07-07',
      });
      // 80 g à 29,5 kcal/100 g : la valeur de L'INSTANTANÉ, pas celle de la v2.
      expect(corrected.components[1]).toMatchObject({
        id: brocoli.id,
        quantityG: 80,
        kcal: 23.6,
        sourceVersion: '2020-07-07',
      });

      // Une ligne NEUVE lit la base du jour : 50 g à 30,5 kcal/100 g.
      const extended = data<MealEntry>(
        await authed()
          .patch(mealUrl(before.id))
          .send({ components: [cuisse, { ...brocoli, quantityG: 80 }, line(BROCOLI, 50)] })
          .expect(200),
      );
      expect(extended.components[2]).toMatchObject({ kcal: 15.3, sourceVersion: '2099-01-01' });

      // Et l'aliment retiré n'entre plus dans un repas sous un identifiant neuf.
      const refused = await authed()
        .patch(mealUrl(before.id))
        .send({ components: [line(CUISSE, 100)] })
        .expect(400);
      expect(errorOf(refused)).toContain(String(CUISSE));

      // La base reste en v2 pour les suites suivantes, comme après `nutrition-foods`.
    });
  });
});
