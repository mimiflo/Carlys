import { Prisma } from '@prisma/client';
import { type FoodSearchRow, type FoodsRepository } from '../infrastructure/foods.repository';
import { FoodsService } from './foods.service';

const EDAMAME: FoodSearchRow = {
  code: 20_904,
  name: 'Soja, graine entière',
  shortName: 'Soja',
  groupName: 'légumineuses',
  kcalPer100g: new Prisma.Decimal(416),
  kcalComputed: false,
  proteinPer100g: new Prisma.Decimal(36),
  carbsPer100g: new Prisma.Decimal(10),
  fatPer100g: new Prisma.Decimal(20),
};

describe('FoodsService.closest', () => {
  /** Une base qui ne connaît que le soja : chaque tête essayée est notée. */
  function service() {
    const heads: string[] = [];
    const repository = {
      closest: (head: string) => {
        heads.push(head);
        return Promise.resolve(head === 'soja' ? EDAMAME : null);
      },
    };
    return { foods: new FoodsService(repository as unknown as FoodsRepository), heads };
  }

  it('l’aliment d’abord, puis, faute de lui, un autre nom du libellé', async () => {
    const { foods, heads } = service();
    const food = await foods.closest('Fèves de soja, cuites');
    expect(food?.code).toBe(20_904);
    expect(heads).toEqual(['feve', 'soja']);
  });

  it('rien de tel dans la base : null, sans erreur', async () => {
    const { foods } = service();
    expect(await foods.closest('Sauce mystère')).toBeNull();
    expect(await foods.closest('!!')).toBeNull();
  });
});
