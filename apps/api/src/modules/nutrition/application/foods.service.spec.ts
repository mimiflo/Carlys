import { Prisma } from '@prisma/client';
import { type FoodSearchRow, type FoodsRepository } from '../infrastructure/foods.repository';
import { FoodsService } from './foods.service';

const POULET: FoodSearchRow = {
  code: 36_018,
  name: 'Poulet, filet, sans peau, cuit',
  shortName: 'Poulet',
  groupName: 'viandes',
  kcalPer100g: new Prisma.Decimal(121),
  proteinPer100g: new Prisma.Decimal(26),
  carbsPer100g: new Prisma.Decimal(0),
  fatPer100g: new Prisma.Decimal(1.6),
};

describe('FoodsService.closest', () => {
  /** Une base qui ne connaît que le poulet : chaque mot cherché doit y figurer. */
  function service() {
    const searched: string[][] = [];
    const repository = {
      search: (words: readonly string[]) => {
        searched.push([...words]);
        return Promise.resolve(
          words.every((word) => 'poulet filet sans peau cuit'.includes(word)) ? [POULET] : [],
        );
      },
    };
    return { foods: new FoodsService(repository as unknown as FoodsRepository), searched };
  }

  it('la préparation cède d’abord : « grillé » absent, « poulet filet » trouvé', async () => {
    const { foods, searched } = service();
    const food = await foods.closest('Poulet, filet, grillé');
    expect(food?.code).toBe(36_018);
    expect(searched).toEqual([
      ['poulet', 'filet', 'grille'],
      ['poulet', 'filet'],
    ]);
  });

  it('rien de tel dans la base : null, sans erreur', async () => {
    const { foods } = service();
    expect(await foods.closest('Sauce mystère')).toBeNull();
    expect(await foods.closest('!!')).toBeNull();
  });
});
