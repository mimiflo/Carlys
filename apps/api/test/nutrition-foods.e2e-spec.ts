process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import {
  type ApiErrorEnvelope,
  type ApiSuccessEnvelope,
  type AuthResult,
  type Food,
  type FoodSourceMeta,
  type MealEntry,
} from '@carlys/api-contracts';
import { type INestApplication } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import {
  copyFileSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../src/app/app.module';
import { configureApp } from '../src/app/configure-app';
import { importCiqualDirectory } from '../src/modules/nutrition/infrastructure/ciqual/ciqual-import';

/**
 * Base d'aliments et repas COMPOSÉS : recherche, calcul côté serveur, règles
 * d'ambiguïté, retrait de la composition, lecture d'un repas, moment, et
 * retrait d'un aliment entre deux versions de la table.
 *
 * La base est chargée par le chemin de production (`importCiqualDirectory`,
 * celui de `dist/cli/ciqual-import`) depuis le JEU D'ESSAI au format de la
 * distribution — codes et valeurs illustratifs, voir
 * `test/fixtures/ciqual/README.md`.
 */
const FIXTURES = join(__dirname, 'fixtures', 'ciqual');
const POULET = 990001;
const RIZ = 990002;
const BROCOLI = 990003;
const EAU = 990004;
const GALETTE = 990006;
const CUISSE = 990008;

describe('Nutrition : base d’aliments et repas composés (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaClient;
  let accessToken: string;
  let otherToken: string;
  const emails = [
    `e2e-aliments-${randomUUID()}@carlys.test`,
    `e2e-aliments-autre-${randomUUID()}@carlys.test`,
  ];

  const body = <T>(response: { body: unknown }): T => (response.body as ApiSuccessEnvelope<T>).data;
  const errorOf = (response: { body: unknown }): string =>
    (response.body as ApiErrorEnvelope).error.message;

  const as = (token: string) => ({
    get: (url: string) =>
      request(app.getHttpServer()).get(url).set('Authorization', `Bearer ${token}`),
    patch: (url: string) =>
      request(app.getHttpServer()).patch(url).set('Authorization', `Bearer ${token}`),
    post: (url: string) =>
      request(app.getHttpServer()).post(url).set('Authorization', `Bearer ${token}`),
    delete: (url: string) =>
      request(app.getHttpServer()).delete(url).set('Authorization', `Bearer ${token}`),
  });
  const authed = () => as(accessToken);

  /** Une ligne neuve : son identifiant naît sur l'appareil, unique dans tout le journal. */
  const line = (foodCode: number, quantityG: number) => ({
    id: randomUUID(),
    foodCode,
    quantityG,
  });
  /** Les trois aliments de la maquette : 120 + 150 + 50 g = 320 g. */
  const maquette = () => [line(POULET, 120), line(RIZ, 150), line(BROCOLI, 50)];

  async function composedMeal(components: object[], extra: object = {}): Promise<MealEntry> {
    const response = await authed()
      .post('/api/v1/nutrition/meals')
      .send({
        id: randomUUID(),
        name: 'Poulet, riz et brocoli',
        eatenAt: new Date().toISOString(),
        components,
        ...extra,
      })
      .expect(201);
    return body<MealEntry>(response);
  }

  async function register(email: string): Promise<string> {
    const response = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email, password: 'MotDePasseSolide42', displayName: 'E2E' })
      .expect(201);
    return body<AuthResult>(response).tokens.accessToken;
  }

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleFixture.createNestApplication<NestExpressApplication>();
    configureApp(app as NestExpressApplication);
    await app.init();

    // Version 1 du jeu d'essai, par le chemin de la commande de production.
    await importCiqualDirectory(prisma, join(FIXTURES, 'v1'));
    [accessToken, otherToken] = (await Promise.all(emails.map(register))) as [string, string];
  });

  afterAll(async () => {
    // Les repas et leurs composants partent avec les comptes (cascade) ; les
    // aliments restent, comme en production : l'import est rejouable.
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
    await prisma.$disconnect();
    await app.close();
  });

  describe('recherche', () => {
    it('cherche chaque mot, classe « commence par » puis nom court, et cite la source', async () => {
      const response = await authed().get('/api/v1/nutrition/foods?q=riz').expect(200);
      const foods = body<Food[]>(response);
      const meta = (response.body as ApiSuccessEnvelope<Food[], FoodSourceMeta>).meta;

      expect(foods.map((food) => food.code)).toEqual([RIZ, 990007, GALETTE]);
      expect(foods[0]).toEqual({
        code: RIZ,
        name: 'Riz blanc, cuit',
        shortName: 'Riz blanc',
        group: 'produits céréaliers',
        per100g: { kcal: 130, proteinG: 2.7, carbsG: 28.6, fatG: 0.3 },
      });
      expect(meta.source).toEqual({
        attribution: 'Source : Anses, Table de composition nutritionnelle des aliments Ciqual',
        version: '2020-07-07',
        license: 'Licence Ouverte Etalab 2.0',
        url: 'https://ciqual.anses.fr/',
      });
    });

    it('tous les mots doivent y être, sans égard aux accents ni aux ligatures', async () => {
      const both = body<Food[]>(
        await authed()
          .get(`/api/v1/nutrition/foods?q=${encodeURIComponent('POULET cuit')}`)
          .expect(200),
      );
      expect(both.map((food) => food.code)).toEqual([POULET]);
      for (const q of ['oeuf', 'œuf', 'Œuf dur']) {
        const eggs = body<Food[]>(
          await authed()
            .get(`/api/v1/nutrition/foods?q=${encodeURIComponent(q)}`)
            .expect(200),
        );
        expect(eggs.map((food) => food.shortName)).toEqual(['Œuf']);
      }
    });

    it('« - », « traces », « < 0,5 » : null, 0, 0 ; un aliment sans énergie n’existe pas', async () => {
      const galette = body<Food>(
        await authed().get(`/api/v1/nutrition/foods/${GALETTE}`).expect(200),
      );
      expect(galette.per100g.fatG).toBeNull();
      const poulet = body<Food>(
        await authed().get(`/api/v1/nutrition/foods/${POULET}`).expect(200),
      );
      expect(poulet.per100g.carbsG).toBe(0);
      const brocoli = body<Food>(
        await authed().get(`/api/v1/nutrition/foods/${BROCOLI}`).expect(200),
      );
      expect(brocoli.per100g.fatG).toBe(0);
      await authed().get(`/api/v1/nutrition/foods/${EAU}`).expect(404);
      expect(
        body<Food[]>(await authed().get('/api/v1/nutrition/foods?q=eau robinet').expect(200)),
      ).toEqual([]);
    });

    it('borne la saisie et la limite, et exige d’être connecté', async () => {
      await authed().get('/api/v1/nutrition/foods?q=r').expect(400);
      await authed()
        .get(`/api/v1/nutrition/foods?q=${'r'.repeat(61)}`)
        .expect(400);
      await authed().get('/api/v1/nutrition/foods?q=riz&limit=31').expect(400);
      await authed().get('/api/v1/nutrition/foods?q=riz&limit=0').expect(400);
      await authed().get('/api/v1/nutrition/foods').expect(400);
      const limited = body<Food[]>(
        await authed().get('/api/v1/nutrition/foods?q=riz&limit=1').expect(200),
      );
      expect(limited).toHaveLength(1);
      // Rien à chercher : une liste vide, pas une erreur.
      expect(body<Food[]>(await authed().get('/api/v1/nutrition/foods?q=!!').expect(200))).toEqual(
        [],
      );
      await request(app.getHttpServer()).get('/api/v1/nutrition/foods?q=riz').expect(401);
      await authed().get('/api/v1/nutrition/foods/pas-un-code').expect(400);
      await authed().get('/api/v1/nutrition/foods/99999999999').expect(404);
    });
  });

  describe('repas composé', () => {
    it('le serveur calcule kcal, macros et quantité depuis les aliments (maquette : 320 g)', async () => {
      const lines = maquette();
      const meal = await composedMeal(lines, { moment: 'LUNCH' });

      expect(meal).toMatchObject({
        moment: 'LUNCH',
        // 180 + 195 + 14,75 = 389,75.
        kcal: 390,
        // 34,8 + 4,05 + 1,2 ; 0 + 42,9 + 1,05 ; 4,32 + 0,45 + 0.
        proteinG: 40,
        carbsG: 44,
        fatG: 5,
        quantity: 320,
        quantityUnit: 'GRAM',
        computed: true,
      });
      expect(meal.components).toEqual([
        {
          id: lines[0]?.id,
          foodCode: POULET,
          name: 'Poulet, filet, sans peau, cuit',
          shortName: 'Poulet',
          group: 'viandes, œufs, poissons et assimilés',
          sourceVersion: '2020-07-07',
          quantityG: 120,
          kcal: 180,
          proteinG: 34.8,
          carbsG: 0,
          fatG: 4.3,
        },
        expect.objectContaining({ foodCode: RIZ, quantityG: 150, kcal: 195, proteinG: 4.1 }),
        expect.objectContaining({ foodCode: BROCOLI, quantityG: 50, kcal: 14.8, fatG: 0 }),
      ]);

      // La lecture d'un repas rend exactement la même chose.
      const read = body<MealEntry>(
        await authed().get(`/api/v1/nutrition/meals/${meal.id}`).expect(200),
      );
      expect(read).toEqual(meal);
    });

    it('une macro inconnue d’UN aliment rend le total inconnu, jamais un zéro', async () => {
      const meal = await composedMeal([line(POULET, 100), line(GALETTE, 30)]);
      expect(meal.fatG).toBeNull();
      expect(meal.proteinG).toBe(32);
    });

    it('refuse l’ambiguïté : des aliments ET des totaux dans le même corps', async () => {
      for (const extra of [
        { kcal: 500 },
        { proteinG: null },
        { quantity: 320, quantityUnit: 'GRAM' },
      ]) {
        const response = await authed()
          .post('/api/v1/nutrition/meals')
          .send({
            id: randomUUID(),
            name: 'Ambigu',
            eatenAt: new Date().toISOString(),
            components: maquette(),
            ...extra,
          })
          .expect(400);
        expect(errorOf(response)).toMatch(/n’envoie pas/);
      }
      // Ni aliments ni calories : rien ne dit ce que vaut ce repas.
      await authed()
        .post('/api/v1/nutrition/meals')
        .send({ id: randomUUID(), name: 'Vide', eatenAt: new Date().toISOString(), components: [] })
        .expect(400);
    });

    it('refuse un aliment inconnu en nommant son code, et les compositions hors bornes', async () => {
      const unknown = await authed()
        .post('/api/v1/nutrition/meals')
        .send({
          id: randomUUID(),
          name: 'Mystère',
          eatenAt: new Date().toISOString(),
          components: [line(123456, 100)],
        })
        .expect(400);
      expect(errorOf(unknown)).toContain('123456');

      const invalid = [
        [line(POULET, 0.5)],
        [line(POULET, 5_001)],
        [line(POULET, 12.345)],
        [{ id: randomUUID(), foodCode: POULET }],
        [{ ...line(POULET, 100), name: 'intrus' }],
        [{ ...line(POULET, 100), id: 'pas-un-uuid' }],
        Array.from({ length: 31 }, () => line(POULET, 10)),
      ];
      for (const components of invalid) {
        await authed()
          .post('/api/v1/nutrition/meals')
          .send({
            id: randomUUID(),
            name: 'Hors bornes',
            eatenAt: new Date().toISOString(),
            components,
          })
          .expect(400);
      }
    });

    it('les totaux d’un repas composé ne se corrigent pas à la main', async () => {
      const meal = await composedMeal(maquette());
      const url = `/api/v1/nutrition/meals/${meal.id}`;

      const locked = await authed().patch(url).send({ kcal: 350 }).expect(400);
      expect(errorOf(locked)).toMatch(/retire d’abord sa composition/);
      await authed().patch(url).send({ components: maquette(), fatG: 3 }).expect(400);
      await authed().patch(url).send({ components: null }).expect(400);

      // Le nom, le moment et l'heure restent libres, et la composition ne bouge pas.
      const renamed = body<MealEntry>(
        await authed().patch(url).send({ name: 'Déjeuner', moment: 'DINNER' }).expect(200),
      );
      expect(renamed).toMatchObject({
        name: 'Déjeuner',
        moment: 'DINNER',
        kcal: 390,
        computed: true,
      });
      expect(renamed.components).toHaveLength(3);
    });

    it('une nouvelle composition remplace l’ancienne et recalcule tout', async () => {
      const meal = await composedMeal(maquette());

      const replaced = body<MealEntry>(
        await authed()
          .patch(`/api/v1/nutrition/meals/${meal.id}`)
          .send({ components: [line(RIZ, 200)] })
          .expect(200),
      );
      expect(replaced).toMatchObject({
        kcal: 260,
        quantity: 200,
        quantityUnit: 'GRAM',
        computed: true,
      });
      expect(replaced.components.map((component) => component.foodCode)).toEqual([RIZ]);
    });

    it('retirer la composition garde les derniers totaux, puis rend la main', async () => {
      const meal = await composedMeal(maquette());
      const url = `/api/v1/nutrition/meals/${meal.id}`;

      const manual = body<MealEntry>(
        await authed().patch(url).send({ components: [] }).expect(200),
      );
      expect(manual).toMatchObject({
        kcal: 390,
        proteinG: 40,
        quantity: 320,
        quantityUnit: 'GRAM',
        components: [],
        computed: false,
      });

      const corrected = body<MealEntry>(await authed().patch(url).send({ kcal: 420 }).expect(200));
      expect(corrected.kcal).toBe(420);
    });
  });

  describe('lecture d’un repas et moment', () => {
    it('un repas saisi à la main porte son moment, que null efface', async () => {
      const id = randomUUID();
      await authed()
        .post('/api/v1/nutrition/meals')
        .send({ id, name: 'Pomme', kcal: 80, moment: 'SNACK', eatenAt: new Date().toISOString() })
        .expect(201);
      const url = `/api/v1/nutrition/meals/${id}`;
      expect(body<MealEntry>(await authed().get(url).expect(200))).toMatchObject({
        moment: 'SNACK',
        components: [],
        computed: false,
      });

      await authed().patch(url).send({ moment: 'BRUNCH' }).expect(400);
      const cleared = body<MealEntry>(await authed().patch(url).send({ moment: null }).expect(200));
      expect(cleared.moment).toBeNull();

      await authed()
        .post('/api/v1/nutrition/meals')
        .send({
          id: randomUUID(),
          name: 'Goûter',
          kcal: 80,
          moment: 'GOUTER',
          eatenAt: new Date().toISOString(),
        })
        .expect(400);
    });

    it('404 indiscernable : inconnu, d’autrui, ou supprimé', async () => {
      const meal = await composedMeal(maquette());
      const url = `/api/v1/nutrition/meals/${meal.id}`;

      const foreign = await as(otherToken).get(url).expect(404);
      const unknown = await authed().get(`/api/v1/nutrition/meals/${randomUUID()}`).expect(404);
      await authed().delete(url).expect(204);
      const deleted = await authed().get(url).expect(404);
      expect(errorOf(foreign)).toBe(errorOf(unknown));
      expect(errorOf(deleted)).toBe(errorOf(unknown));
      await authed().get('/api/v1/nutrition/meals/pas-un-uuid').expect(400);
    });

    it('la liste du jour porte les composants', async () => {
      const meal = await composedMeal(maquette());
      const from = new Date(Date.now() - 3_600_000).toISOString();
      const to = new Date(Date.now() + 3_600_000).toISOString();
      const meals = body<MealEntry[]>(
        await authed().get(`/api/v1/nutrition/meals?from=${from}&to=${to}`).expect(200),
      );
      expect(meals.find((candidate) => candidate.id === meal.id)?.components).toHaveLength(3);
    });
  });

  describe('nouvelle version de la table', () => {
    it('retire l’aliment disparu, garde l’instantané des repas, et se rejoue sans effet', async () => {
      const lines = [line(CUISSE, 100), line(BROCOLI, 50)];
      const before = await composedMeal(lines);

      const report = await importCiqualDirectory(prisma, join(FIXTURES, 'v2'));
      expect(report).toMatchObject({
        version: '2099-01-01',
        created: 0,
        retired: 1,
        reactivated: 0,
      });
      // Toutes les lignes actives changent de version, le brocoli de valeur aussi.
      expect(report.updated).toBe(6);

      // L'instantané fait foi : le repas ne bouge pas, ni la cuisse retirée ni
      // le brocoli à 29,5 kcal/100 g (30,5 dans la nouvelle version).
      const after = body<MealEntry>(
        await authed().get(`/api/v1/nutrition/meals/${before.id}`).expect(200),
      );
      expect(after).toEqual(before);
      expect(after.components[1]?.kcal).toBe(14.8);

      // Le REJEU de sa création (file de synchronisation hors ligne) rend le
      // repas écrit, sans recomposer : la cuisse retirée n'y fait pas un 400.
      const replayed = await authed()
        .post('/api/v1/nutrition/meals')
        .send({
          id: before.id,
          name: before.name,
          eatenAt: before.eatenAt,
          components: lines,
        })
        .expect(201);
      expect(body<MealEntry>(replayed)).toEqual(before);

      // Mais l'aliment retiré n'entre plus dans un repas sous une ligne NEUVE,
      // ni dans la recherche. (Désignée par son identifiant, la ligne déjà
      // enregistrée le garde : `nutrition-meal-corrections.e2e-spec.ts`.)
      const refused = await authed()
        .patch(`/api/v1/nutrition/meals/${before.id}`)
        .send({ components: [line(CUISSE, 100)] })
        .expect(400);
      expect(errorOf(refused)).toContain(String(CUISSE));
      await authed().get(`/api/v1/nutrition/foods/${CUISSE}`).expect(404);
      const search = await authed().get('/api/v1/nutrition/foods?q=poulet').expect(200);
      expect(body<Food[]>(search).map((food) => food.code)).toEqual([POULET]);
      expect((search.body as ApiSuccessEnvelope<Food[], FoodSourceMeta>).meta.source.version).toBe(
        '2099-01-01',
      );

      // Une ligne NEUVE relit la base : 50 g de brocoli à 30,5.
      const recomposed = body<MealEntry>(
        await authed()
          .patch(`/api/v1/nutrition/meals/${before.id}`)
          .send({ components: [line(BROCOLI, 50)] })
          .expect(200),
      );
      expect(recomposed.components[0]).toMatchObject({ kcal: 15.3, sourceVersion: '2099-01-01' });

      // Rejouer la même version : rien ne change.
      const replay = await importCiqualDirectory(prisma, join(FIXTURES, 'v2'));
      expect(replay).toMatchObject({
        created: 0,
        updated: 0,
        reactivated: 0,
        retired: 0,
        unchanged: 6,
      });
    });

    it('une simulation (--a-blanc) compte sans écrire', async () => {
      const simulation = await importCiqualDirectory(prisma, join(FIXTURES, 'v1'), {
        dryRun: true,
      });
      expect(simulation).toMatchObject({ dryRun: true, reactivated: 1, updated: 6 });
      await authed().get(`/api/v1/nutrition/foods/${CUISSE}`).expect(404);
    });

    it('un dossier incomplet échoue sans rien écrire', async () => {
      await expect(importCiqualDirectory(prisma, FIXTURES)).rejects.toThrow(/fichier introuvable/);
    });

    it('refuse de retirer plus d’un quart de la base sans --accepter-retraits', async () => {
      // La v2 amputée de tous ses aliments sauf le poulet : un `alim_*.xml`
      // tronqué pile entre deux aliments ressemblerait exactement à ça.
      const directory = mkdtempSync(join(tmpdir(), 'ciqual-ampute-'));
      try {
        for (const file of readdirSync(join(FIXTURES, 'v2'))) {
          copyFileSync(join(FIXTURES, 'v2', file), join(directory, file));
        }
        const alim = join(directory, 'alim_2099_01_01.xml');
        const kept = readFileSync(alim, 'latin1').replace(
          /<ALIM>(?:(?!<\/ALIM>)[\s\S])*?<alim_code> (?!990001 )\d+ <\/alim_code>[\s\S]*?<\/ALIM>\n/g,
          '',
        );
        writeFileSync(alim, kept, 'latin1');

        await expect(importCiqualDirectory(prisma, directory)).rejects.toThrow(
          /retirerait 5 aliments sur les 6/,
        );
        // Rien n'a été écrit : le riz est toujours en service.
        await authed().get(`/api/v1/nutrition/foods/${RIZ}`).expect(200);

        const accepted = await importCiqualDirectory(prisma, directory, {
          allowMassRetirement: true,
        });
        expect(accepted).toMatchObject({ retired: 5, massRetirement: true });
        await authed().get(`/api/v1/nutrition/foods/${RIZ}`).expect(404);
      } finally {
        rmSync(directory, { recursive: true, force: true });
        // La base retrouve la v2 entière : les retirés reviennent.
        const restored = await importCiqualDirectory(prisma, join(FIXTURES, 'v2'));
        expect(restored.reactivated).toBe(5);
      }
    });
  });
});
