import {
  type MealComponent as MealComponentContract,
  type MealEntry as MealEntryContract,
  type MealMeta,
} from '@carlys/api-contracts';
import { type MealComponent, type Prisma } from '@prisma/client';
import { ciqualAttribution } from '../domain/ciqual-source';
import { componentValues, roundHalfUp } from '../domain/meal-composition';
import { type MealWithComponents } from '../infrastructure/meals.repository';

/** Les valeurs d'un composant se lisent au dixième : « 1,2 g », « 185,6 kcal ». */
const COMPONENT_PLACES = 1;

function tenth(value: Prisma.Decimal | null): number | null {
  return value === null ? null : roundHalfUp(value, COMPONENT_PLACES);
}

/**
 * Un composant tel que le client le lit : l'INSTANTANÉ pris à l'ajout, et
 * ses valeurs pour SA quantité, recalculées depuis cet instantané — jamais
 * depuis la base, qu'une nouvelle version de CIQUAL a pu changer depuis.
 */
export function presentComponent(component: MealComponent): MealComponentContract {
  const values = componentValues(component);
  return {
    id: component.id,
    foodCode: component.foodCode,
    name: component.foodName,
    shortName: component.foodShortName,
    group: component.foodGroup,
    sourceVersion: component.foodSourceVersion,
    quantityG: component.quantityG.toNumber(),
    kcal: roundHalfUp(values.kcal, COMPONENT_PLACES),
    proteinG: tenth(values.proteinG),
    carbsG: tenth(values.carbsG),
    fatG: tenth(values.fatG),
  };
}

export function presentMeal(meal: MealWithComponents): MealEntryContract {
  return {
    id: meal.id,
    name: meal.name,
    moment: meal.moment,
    kcal: meal.kcal,
    // `Decimal` ne traverse pas JSON : sérialisé tel quel, il devient une
    // CHAÎNE côté client, que `z.number()` refuserait. La conversion est
    // sans perte — deux décimales tiennent très en deçà de la précision d'un
    // double, et la colonne n'en accepte pas plus.
    quantity: meal.quantity === null ? null : meal.quantity.toNumber(),
    quantityUnit: meal.quantityUnit,
    proteinG: meal.proteinG,
    carbsG: meal.carbsG,
    fatG: meal.fatG,
    eatenAt: meal.eatenAt.toISOString(),
    components: meal.components.map(presentComponent),
    computed: meal.components.length > 0,
    photo: meal.photo === null ? null : { updatedAt: meal.photo.updatedAt.toISOString() },
  };
}

/**
 * `meta` d'une réponse de repas : la mention de source dès qu'UN repas rendu
 * montre des valeurs de la table CIQUAL (Licence Ouverte Etalab 2.0 : pas de
 * réutilisation sans elle). La date de mise à jour exigée avec elle est la
 * `sourceVersion` de chaque ligne. Rien pour des repas saisis à la main.
 */
export function mealMeta(meals: readonly MealEntryContract[]): MealMeta {
  return meals.some((meal) => meal.components.length > 0) ? { source: ciqualAttribution() } : {};
}
