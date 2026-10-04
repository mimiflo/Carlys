process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.DATABASE_URL ??= 'postgresql://carlys:carlys@localhost:5432/carlys_test';
process.env.REDIS_URL ??= 'redis://localhost:6379';
process.env.JWT_ACCESS_SECRET ??= 'secret-e2e-uniquement-32-caracteres-minimum';

import { type INestApplicationContext } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../src/app/app.module';
import { FoodsService } from '../src/modules/nutrition/application/foods.service';
import { normalizeFoodText, shortFoodName } from '../src/modules/nutrition/domain/food-text';

/**
 * Le rapprochement d'un nom du modèle de vision (ADR 0015), sur une VRAIE
 * requête PostgreSQL et des noms de la table CIQUAL 2020 choisis pour leurs
 * pièges : le bœuf aux carottes, la pâte sablée, le saumon fumé, le poisson
 * pour « pois », les oeufs de lompe. Chaque critère du classement a un cas
 * où il est SEUL à décider. Codes réservés à ce fichier, retirés à la fin.
 *
 * La requête parcourt toute la table : ce fichier suppose la base d'e2e,
 * qui ne porte que le jeu d'essai (`fixtures/ciqual`) ; sur une base où la
 * vraie table est importée, d'autres aliments pourraient l'emporter.
 */
const NAMES = [
  'Haricot vert, cuit',
  'Haricot vert, surgelé, cru',
  'Carotte, cuite',
  'Boeuf aux carottes',
  'Pâte sablée, cuite',
  'Pâtes sèches standard, cuites, non salées',
  'Pâtes à la carbonara (spaghetti, tagliatelles…)',
  'Saumon fumé',
  'Saumon, cru, élevage',
  'Saumon, grillé/poêlé',
  'Yaourt à la grecque, au lait de brebis',
  'Yaourt ou spécialité laitière nature (aliment moyen)',
  'Huile de soja',
  'Soja, graine entière',
  'Courgette, crue',
  'Courgette, bouillie',
  'Fromage de chèvre',
  'Fromage (aliment moyen)',
  'Pois chiche, bouilli/cuit à l’eau',
  'Poisson cuit (aliment moyen)',
  'Oeuf, brouillé, avec matière grasse',
  'Oeufs de lompe, semi-conserve',
  'Avocat, pulpe, cru',
  'Huile d’avocat',
];
const FIRST_CODE = 970_001;

describe('Rapprochement d’un nom libre avec la table CIQUAL (e2e)', () => {
  let app: INestApplicationContext;
  let prisma: PrismaClient;
  let foods: FoodsService;
  const codes = NAMES.map((_, index) => FIRST_CODE + index);

  beforeAll(async () => {
    prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });
    await prisma.food.deleteMany({ where: { code: { in: codes } } });
    await prisma.food.createMany({
      data: NAMES.map((name, index) => ({
        code: FIRST_CODE + index,
        name,
        shortName: shortFoodName(name),
        searchKey: normalizeFoodText(name),
        kcalPer100g: 100,
        sourceVersion: 'e2e-rapprochement',
      })),
    });
    const moduleFixture = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = await moduleFixture.createNestApplication().init();
    foods = app.get(FoodsService);
  });

  afterAll(async () => {
    await prisma.food.deleteMany({ where: { code: { in: codes } } });
    await prisma.$disconnect();
    await app.close();
  });

  it.each([
    // Le pluriel et l'accord : « haricots verts » n'est pas absent de la base.
    ['Haricots verts, cuits', 'Haricot vert, cuit'],
    // Le nom d'abord : pas le « bœuf aux carottes ».
    ['Carottes, cuites', 'Carotte, cuite'],
    // « pâtes » n'est pas « pâte » (sablée), et « cuites » pèse plus que « spaghetti ».
    ['Pâtes, spaghetti, cuites', 'Pâtes sèches standard, cuites, non salées'],
    ['Saumon, filet, grillé', 'Saumon, grillé/poêlé'],
    ['Yaourt, nature', 'Yaourt ou spécialité laitière nature (aliment moyen)'],
    // Mots entiers : « pois » ne trouve pas le poisson, « oeuf » pas le bœuf.
    ['Pois chiches', 'Pois chiche, bouilli/cuit à l’eau'],
    // Le pluriel du nom ne compte pas double : pas les oeufs de lompe.
    ['Oeufs brouillés', 'Oeuf, brouillé, avec matière grasse'],
    // L'anglais qui échappe au modèle est traduit.
    ['Avocado, coupé', 'Avocat, pulpe, cru'],
  ])('« %s » → « %s »', async (seen, expected) => {
    expect((await foods.closest(seen))?.name).toBe(expected);
  });

  it('rôti, donc pas cru : le malus « cru » décide seul (sinon, le plus court)', async () => {
    expect((await foods.closest('Courgette, rôtie'))?.name).toBe('Courgette, bouillie');
  });

  it('« commence par » décide seul : le soja, pas l’huile de soja (plus courte)', async () => {
    expect((await foods.closest('Soja'))?.name).toBe('Soja, graine entière');
  });

  it('la mention « (aliment moyen) » ne compte pas dans la longueur : elle décide seule', async () => {
    expect((await foods.closest('Fromage'))?.name).toBe('Fromage (aliment moyen)');
  });

  it('un aliment absent de la base : null, pas son plus proche voisin de rayon', async () => {
    expect(await foods.closest('Edamame, cuits')).toBeNull();
  });
});
