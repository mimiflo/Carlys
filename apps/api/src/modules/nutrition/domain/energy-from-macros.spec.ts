import { Prisma } from '@prisma/client';
import { energyFromMacros } from './energy-from-macros';

const d = (value: number) => new Prisma.Decimal(value);

describe('energyFromMacros', () => {
  it('les facteurs du règlement UE 1169/2011 : 4, 4, 9, fibres 2, alcool 7, acides 3, polyols 2,4', () => {
    // Laitue crue, CIQUAL 2020 (énergie absente de la table).
    expect(
      energyFromMacros({ protein: d(1.3), carbs: d(1.33), fat: d(0.2), fibre: d(1.2) })?.toNumber(),
    ).toBe(14.7);
    // 10 g de polyols comptés dans les glucides valent 2,4 kcal/g, pas 4.
    expect(
      energyFromMacros({
        protein: d(0),
        carbs: d(50),
        fat: d(0),
        polyols: d(10),
        alcohol: d(1),
        organicAcids: d(1),
      })?.toNumber(),
    ).toBe(194);
  });

  it('des polyols plus nombreux que les glucides (incohérence) : jamais négatif', () => {
    expect(
      energyFromMacros({ protein: d(0), carbs: d(0), fat: d(0), polyols: d(0.5) })?.toNumber(),
    ).toBe(0);
  });

  it('une teneur secondaire inconnue compte pour zéro', () => {
    expect(
      energyFromMacros({ protein: d(10), carbs: d(10), fat: d(10), fibre: null })?.toNumber(),
    ).toBe(170);
  });

  it('sans protéines, glucides ou lipides connus : on ne sait pas', () => {
    expect(energyFromMacros({ protein: null, carbs: d(10), fat: d(10) })).toBeNull();
    expect(energyFromMacros({ protein: d(1), carbs: d(10), fat: null })).toBeNull();
  });
});
