import { Prisma } from '@prisma/client';

type Decimal = Prisma.Decimal;
const Decimal = Prisma.Decimal;

/**
 * Le calcul d'un repas COMPOSÉ, en fonctions pures.
 *
 * Tout se fait en décimal exact (`Prisma.Decimal`, c'est-à-dire decimal.js),
 * jamais en flottant : 0,1 + 0,2 ne vaut pas 0,3 en double, et une somme
 * d'une trentaine de produits « valeur pour 100 g × grammes / 100 »
 * accumulerait l'erreur jusqu'à faire basculer un arrondi. L'arrondi n'a
 * lieu qu'UNE fois, sur le total — arrondir chaque composant puis sommer
 * ferait dériver le total d'une calorie par aliment.
 */

/** Ce qu'un composant recopie de la base au moment de l'ajout. */
export interface FoodSnapshot {
  readonly foodCode: number;
  readonly foodName: string;
  readonly foodShortName: string;
  readonly foodGroup: string | null;
  readonly foodSourceVersion: string;
  readonly kcalPer100g: Decimal;
  readonly proteinPer100g: Decimal | null;
  readonly carbsPer100g: Decimal | null;
  readonly fatPer100g: Decimal | null;
}

/** Un aliment d'un repas : son instantané et sa quantité en grammes. */
export interface ComponentSnapshot extends FoodSnapshot {
  readonly quantityG: Decimal;
}

/** Une ligne `MealComponent` prête à écrire (le dépôt pose `mealId`). */
export interface ComponentRow extends ComponentSnapshot {
  /** L'UUID donné par l'appareil à la ligne. */
  readonly id: string;
  readonly position: number;
  /**
   * La date de l'instantané, pour une ligne GARDÉE d'une correction à
   * l'autre ; absente pour une ligne neuve, que la base date à l'écriture.
   */
  readonly createdAt?: Date;
}

/** Les valeurs d'UN composant pour SA quantité (non arrondies). */
export interface ComponentValues {
  readonly kcal: Decimal;
  readonly proteinG: Decimal | null;
  readonly carbsG: Decimal | null;
  readonly fatG: Decimal | null;
}

/** Les totaux d'un repas composé, tels qu'ils s'écrivent sur `MealEntry`. */
export interface CompositionTotals {
  /** Somme arrondie à l'entier (demi vers le haut). */
  readonly kcal: number;
  /** Somme arrondie, ou `null` dès qu'UN composant ignore la macro. */
  readonly proteinG: number | null;
  readonly carbsG: number | null;
  readonly fatG: number | null;
  /** Somme exacte des grammes (deux décimales, comme les quantités). */
  readonly quantityG: Decimal;
}

function scaled(per100g: Decimal | null, quantityG: Decimal): Decimal | null {
  return per100g === null ? null : per100g.mul(quantityG).div(100);
}

export function componentValues(component: ComponentSnapshot): ComponentValues {
  return {
    kcal: component.kcalPer100g.mul(component.quantityG).div(100),
    proteinG: scaled(component.proteinPer100g, component.quantityG),
    carbsG: scaled(component.carbsPer100g, component.quantityG),
    fatG: scaled(component.fatPer100g, component.quantityG),
  };
}

/** Arrondi commercial (demi vers le haut) à `places` décimales. */
export function roundHalfUp(value: Decimal, places: number): number {
  return value.toDecimalPlaces(places, Decimal.ROUND_HALF_UP).toNumber();
}

/**
 * Somme d'une macro sur tous les composants : `null` dès qu'UN composant
 * l'ignore. Compter un inconnu pour zéro afficherait un total faux avec
 * l'aplomb d'un vrai — « 12 g de lipides » là où la table ne sait pas.
 */
function macroTotal(values: readonly (Decimal | null)[]): number | null {
  let total = new Decimal(0);
  for (const value of values) {
    if (value === null) {
      return null;
    }
    total = total.add(value);
  }
  return roundHalfUp(total, 0);
}

export function compositionTotals(components: readonly ComponentSnapshot[]): CompositionTotals {
  const values = components.map(componentValues);
  const kcal = values.reduce((sum, value) => sum.add(value.kcal), new Decimal(0));
  const quantityG = components.reduce(
    (sum, component) => sum.add(component.quantityG),
    new Decimal(0),
  );
  return {
    kcal: roundHalfUp(kcal, 0),
    proteinG: macroTotal(values.map((value) => value.proteinG)),
    carbsG: macroTotal(values.map((value) => value.carbsG)),
    fatG: macroTotal(values.map((value) => value.fatG)),
    quantityG,
  };
}
