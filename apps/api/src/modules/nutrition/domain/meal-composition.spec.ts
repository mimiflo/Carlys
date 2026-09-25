import { Prisma } from '@prisma/client';
import {
  type ComponentSnapshot,
  componentValues,
  compositionTotals,
  roundHalfUp,
} from './meal-composition';

const d = (value: string | number): Prisma.Decimal => new Prisma.Decimal(value);

function component(
  quantityG: number,
  per100g: { kcal: number; protein: number | null; carbs: number | null; fat: number | null },
): ComponentSnapshot {
  return {
    foodCode: 1,
    foodName: 'Aliment, précision',
    foodShortName: 'Aliment',
    foodGroup: null,
    foodSourceVersion: 'essai',
    kcalPer100g: d(per100g.kcal),
    proteinPer100g: per100g.protein === null ? null : d(per100g.protein),
    carbsPer100g: per100g.carbs === null ? null : d(per100g.carbs),
    fatPer100g: per100g.fat === null ? null : d(per100g.fat),
    quantityG: d(quantityG),
  };
}

// Les trois aliments de la maquette, valeurs du jeu d'essai (illustratives).
const poulet = component(120, { kcal: 150, protein: 29, carbs: 0, fat: 3.6 });
const riz = component(150, { kcal: 130, protein: 2.7, carbs: 28.6, fat: 0.3 });
const brocoli = component(50, { kcal: 29.5, protein: 2.4, carbs: 2.1, fat: 0 });

describe('componentValues', () => {
  it('ramène les valeurs pour 100 g à la quantité du composant', () => {
    const values = componentValues(riz);
    expect(values.kcal.toNumber()).toBe(195);
    expect(values.proteinG?.toNumber()).toBe(4.05);
    expect(values.carbsG?.toNumber()).toBe(42.9);
  });

  it('une macro inconnue de la table reste inconnue, jamais zéro', () => {
    const values = componentValues(
      component(30, { kcal: 392, protein: 8.5, carbs: 80.1, fat: null }),
    );
    expect(values.fatG).toBeNull();
  });
});

describe('compositionTotals', () => {
  it('somme les composants et n’arrondit qu’une fois, à la fin (120 + 150 + 50 g = 320 g)', () => {
    const totals = compositionTotals([poulet, riz, brocoli]);
    // 180 + 195 + 14,75 = 389,75 → 390.
    expect(totals.kcal).toBe(390);
    // 34,8 + 4,05 + 1,2 = 40,05 → 40.
    expect(totals.proteinG).toBe(40);
    // 0 + 42,9 + 1,05 = 43,95 → 44.
    expect(totals.carbsG).toBe(44);
    // 4,32 + 0,45 + 0 = 4,77 → 5.
    expect(totals.fatG).toBe(5);
    expect(totals.quantityG.toNumber()).toBe(320);
  });

  it('une macro devient inconnue dès qu’UN composant l’ignore', () => {
    const galette = component(30, { kcal: 392, protein: 8.5, carbs: 80.1, fat: null });
    const totals = compositionTotals([poulet, galette]);
    expect(totals.fatG).toBeNull();
    // Les autres restent sommées : l'inconnu d'une macro ne contamine pas les autres.
    expect(totals.proteinG).toBe(37);
  });

  it('calcule en décimal exact : 0,1 + 0,2 font bien 0,3', () => {
    const a = component(100, { kcal: 0.1, protein: 0.25, carbs: 0, fat: 0 });
    const b = component(100, { kcal: 0.2, protein: 0.25, carbs: 0, fat: 0 });
    // En flottant, 0,1 + 0,2 = 0,30000000000000004 ; ici l'égalité est exacte.
    expect(componentValues(a).kcal.add(componentValues(b).kcal).equals(d('0.3'))).toBe(true);
    // Et le demi s'arrondit vers le haut : 0,5 g de protéines font 1 g.
    expect(compositionTotals([a, b]).proteinG).toBe(1);
  });
});

describe('roundHalfUp', () => {
  it('arrondit le demi vers le haut, là où le flottant se trompe', () => {
    // 4,05 n'existe pas en double : `(4.05).toFixed(1)` rend « 4.0 », et
    // `(1.005).toFixed(2)` rend « 1.00 ».
    expect(roundHalfUp(d('4.05'), 1)).toBe(4.1);
    expect(roundHalfUp(d('1.005'), 2)).toBe(1.01);
    expect(roundHalfUp(d('14.75'), 1)).toBe(14.8);
    expect(roundHalfUp(d('389.5'), 0)).toBe(390);
  });
});
