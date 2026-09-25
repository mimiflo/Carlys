import { type MealEntry, type MealMoment } from '@carlys/api-contracts';

/**
 * Un repas du journal tel que le coach le lit.
 *
 * Le contrat de l'écran porte, pour chaque aliment d'un repas composé,
 * identifiant, code, groupe et quatre valeurs : utile à un écran qui les
 * affiche, du bruit dans le contexte d'un modèle, facturé au jeton. Une
 * semaine de repas à trente aliments pèserait des dizaines de milliers de
 * caractères pour dire « 120 g de poulet ». Le coach reçoit donc le repas,
 * son MOMENT (un dîner à 23 h n'est pas une collation, et c'est une donnée
 * enregistrée, pas une déduction de l'heure), ses totaux, et ce qui le
 * compose en clair.
 */
export interface CoachMealView {
  readonly name: string;
  /** `null` : repas enregistré sans moment ; l'heure `eatenAt` reste lisible. */
  readonly moment: MealMoment | null;
  readonly eatenAt: string;
  readonly kcal: number;
  readonly proteinG: number | null;
  readonly carbsG: number | null;
  readonly fatG: number | null;
  readonly quantity: number | null;
  readonly quantityUnit: MealEntry['quantityUnit'];
  /** Vrai quand les totaux sont CALCULÉS depuis `foods`, pas saisis à la main. */
  readonly computed: boolean;
  /** « Poulet, filet, sans peau, cuit : 120 g », dans l'ordre du repas. */
  readonly foods: readonly string[];
}

export function coachMealView(meal: MealEntry): CoachMealView {
  return {
    name: meal.name,
    moment: meal.moment,
    eatenAt: meal.eatenAt,
    kcal: meal.kcal,
    proteinG: meal.proteinG,
    carbsG: meal.carbsG,
    fatG: meal.fatG,
    quantity: meal.quantity,
    quantityUnit: meal.quantityUnit,
    computed: meal.computed,
    foods: meal.components.map((component) => `${component.name} : ${component.quantityG} g`),
  };
}
