import { BadRequestException } from '@nestjs/common';
import { type Food, type MealComponent, Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { type FoodsRepository } from '../infrastructure/foods.repository';
import { composeFrom, MealComposer } from './meal-composer';

/** Une ligne neuve : son identifiant vient de l'appareil. */
const line = (foodCode: number, quantityG: number) => ({ id: randomUUID(), foodCode, quantityG });

function foodRow(code: number, overrides: Partial<Food> = {}): Food {
  return {
    code,
    name: `Aliment ${code}, cuit`,
    shortName: `Aliment ${code}`,
    groupCode: '04',
    groupName: 'viandes, œufs, poissons et assimilés',
    subgroupCode: null,
    subgroupName: null,
    kcalPer100g: new Prisma.Decimal(150),
    proteinPer100g: new Prisma.Decimal(29),
    carbsPer100g: new Prisma.Decimal(0),
    fatPer100g: new Prisma.Decimal('3.6'),
    searchKey: `aliment ${code} cuit`,
    sourceVersion: '2020-07-07',
    retiredAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

function composerWith(foods: Food[]): { composer: MealComposer; findByCodes: jest.Mock } {
  const findByCodes = jest.fn().mockResolvedValue(foods);
  return {
    composer: new MealComposer({ findByCodes } as unknown as FoodsRepository),
    findByCodes,
  };
}

describe('MealComposer', () => {
  it('prend l’instantané de chaque aliment, dans l’ordre, et calcule les totaux', async () => {
    const { composer, findByCodes } = composerWith([foodRow(1), foodRow(2)]);

    const items = [
      line(2, 50),
      line(1, 120),
      // Le même aliment deux fois est permis : deux portions notées à part.
      line(2, 50),
    ];
    const composition = await composer.compose(items);

    // Une seule lecture, codes dédoublonnés.
    expect(findByCodes).toHaveBeenCalledWith([2, 1]);
    // Chaque ligne garde l'identifiant que l'appareil lui a donné.
    expect(composition.rows.map((row) => [row.id, row.position, row.foodCode])).toEqual([
      [items[0]?.id, 0, 2],
      [items[1]?.id, 1, 1],
      [items[2]?.id, 2, 2],
    ]);
    expect(composition.rows[1]).toMatchObject({
      foodName: 'Aliment 1, cuit',
      foodShortName: 'Aliment 1',
      foodGroup: 'viandes, œufs, poissons et assimilés',
      foodSourceVersion: '2020-07-07',
    });
    // 220 g à 150 kcal/100 g.
    expect(composition.totals.kcal).toBe(330);
    expect(composition.totals.quantityG.toNumber()).toBe(220);
  });

  it('refuse un aliment inconnu ou retiré en nommant les codes, sans rien calculer', async () => {
    const { composer } = composerWith([foodRow(1, { retiredAt: new Date() })]);

    const attempt = composer.compose([line(1, 100), line(404, 100)]);

    await expect(attempt).rejects.toBeInstanceOf(BadRequestException);
    await expect(attempt).rejects.toThrow(/aliment inconnu : 404 ; aliment retiré de la base : 1/);
  });

  it('refuse une composition sous une kilocalorie', async () => {
    const { composer } = composerWith([foodRow(1, { kcalPer100g: new Prisma.Decimal('0.4') })]);

    await expect(composer.compose([line(1, 100)])).rejects.toThrow(/moins d’une kilocalorie/);
  });

  it('refuse des totaux calculés hors des bornes d’un repas', async () => {
    const { composer } = composerWith([
      foodRow(1, { kcalPer100g: new Prisma.Decimal(900), fatPer100g: new Prisma.Decimal(100) }),
    ]);

    // 30 × 5 000 g d'huile : 1 350 000 kcal, bien au-delà des 10 000 d'un repas.
    const items = Array.from({ length: 30 }, () => line(1, 5_000));
    await expect(composer.compose(items)).rejects.toThrow(/limite d’un repas/);
    // 1 200 g d'huile : 10 800 kcal.
    await expect(composer.compose([line(1, 1_200)])).rejects.toThrow(/kcal/);
    // 1 100 g d'un aliment à 100 g de lipides mais 1 kcal : la borne des macros.
    const { composer: lean } = composerWith([
      foodRow(1, { kcalPer100g: new Prisma.Decimal(1), fatPer100g: new Prisma.Decimal(100) }),
    ]);
    await expect(lean.compose([line(1, 1_100)])).rejects.toThrow(/lipides/);
    // Deux aliments à 5 000 g : 10 000 g, plus que la colonne `quantity`.
    const { composer: heavy } = composerWith([
      foodRow(1, {
        kcalPer100g: new Prisma.Decimal(1),
        proteinPer100g: null,
        carbsPer100g: null,
        fatPer100g: null,
      }),
    ]);
    await expect(heavy.compose([line(1, 5_000), line(1, 5_000)])).rejects.toThrow(/au total/);
  });
});

describe('composeFrom (correction)', () => {
  /** Une ligne enregistrée en v1 : 150 kcal/100 g, ajoutée il y a longtemps. */
  function storedLine(foodCode: number, overrides: Partial<MealComponent> = {}): MealComponent {
    return {
      id: randomUUID(),
      mealId: 'repas-1',
      foodCode,
      position: 0,
      quantityG: new Prisma.Decimal(100),
      foodName: `Aliment ${foodCode}, cuit`,
      foodShortName: `Aliment ${foodCode}`,
      foodGroup: null,
      foodSourceVersion: '2020-07-07',
      kcalPer100g: new Prisma.Decimal(150),
      proteinPer100g: new Prisma.Decimal(20),
      carbsPer100g: null,
      fatPer100g: new Prisma.Decimal(5),
      createdAt: new Date('2026-01-01T00:00:00Z'),
      ...overrides,
    };
  }

  it('une ligne désignée par son identifiant garde son instantané, même retirée de la base', () => {
    const kept = storedLine(1);
    // La base a changé depuis : l'aliment 1 est retiré, et à 900 kcal.
    const catalog = new Map([
      [1, foodRow(1, { retiredAt: new Date(), kcalPer100g: new Prisma.Decimal(900) })],
    ]);

    const composition = composeFrom([{ id: kept.id, foodCode: 1, quantityG: 200 }], catalog, [
      kept,
    ]);

    expect(composition.rows).toEqual([
      expect.objectContaining({
        id: kept.id,
        foodSourceVersion: '2020-07-07',
        kcalPer100g: new Prisma.Decimal(150),
        createdAt: kept.createdAt,
      }),
    ]);
    // 200 g à 150 kcal/100 g : l'instantané, pas la base.
    expect(composition.totals.kcal).toBe(300);
  });

  it('une ligne à identifiant NEUF lit la base, et y est refusée si l’aliment est retiré', () => {
    const catalog = new Map([
      [1, foodRow(1, { retiredAt: new Date() })],
      [2, foodRow(2, { sourceVersion: '2099-01-01' })],
    ]);

    expect(composeFrom([line(2, 100)], catalog).rows[0]?.foodSourceVersion).toBe('2099-01-01');
    expect(() => composeFrom([line(1, 100)], catalog, [storedLine(1)])).toThrow(
      /aliment retiré de la base : 1/,
    );
  });

  it('changer l’aliment d’une ligne sous le même identifiant, ou doubler un identifiant : refusé', () => {
    const kept = storedLine(1);
    const catalog = new Map([
      [1, foodRow(1)],
      [2, foodRow(2)],
    ]);

    expect(() =>
      composeFrom([{ id: kept.id, foodCode: 2, quantityG: 100 }], catalog, [kept]),
    ).toThrow(new RegExp(`la ligne ${kept.id} désignait un autre aliment`));
    const twice = line(2, 100);
    expect(() => composeFrom([twice, { ...twice, quantityG: 50 }], catalog)).toThrow(
      /identifiant de ligne en double/,
    );
  });
});
