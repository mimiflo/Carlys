import { BadRequestException } from '@nestjs/common';
import { type MealMoment, type MealQuantityUnit, type Prisma } from '@prisma/client';
import { type CompositionTotals } from '../domain/meal-composition';
import { type ComponentRequest, type ComputedValues } from '../domain/meal-write-rules';
import { type MealWithComponents } from '../infrastructure/meals.repository';

/**
 * Ce que le service de repas reçoit et écrit : les formes d'entrée (création,
 * correction) et leur traduction en colonnes. Séparé du service pour que
 * celui-ci ne garde que l'enchaînement des règles.
 */

/**
 * Une quantité et son unité vont ENSEMBLE, dans les deux sens.
 *
 * « 250 » sans unité ne dit rien — grammes ? millilitres ? pièces ? — et
 * « en grammes » sans nombre ne dit rien non plus. L'affichage n'a alors que
 * deux choix, inventer l'autre moitié ou taire la première : mieux vaut
 * refuser la saisie que stocker une phrase qu'on ne saura pas finir.
 */
export function assertPairedQuantity(quantity: number | null, unit: MealQuantityUnit | null): void {
  if ((quantity === null) !== (unit === null)) {
    throw new BadRequestException(
      'La quantité et son unité vont ensemble : donne les deux ou aucune.',
    );
  }
}

/**
 * Un nouveau repas, tel que le client l'envoie.
 *
 * Saisi à la main : `kcal` obligatoire, le reste facultatif. Composé
 * (`components` non vide) : AUCUN des champs calculés — le serveur les tire
 * des aliments.
 */
export interface MealDraft {
  id: string;
  name: string;
  moment?: MealMoment | null;
  kcal?: number;
  quantity?: number | null;
  quantityUnit?: MealQuantityUnit | null;
  proteinG?: number | null;
  carbsG?: number | null;
  fatG?: number | null;
  eatenAt: Date;
  components?: readonly ComponentRequest[];
}

/**
 * Ce qu'une correction peut porter.
 *
 * `undefined` et `null` ne disent PAS la même chose : le premier veut dire
 * « n'y touche pas », le second « efface ». Seuls les champs qui peuvent
 * légitimement redevenir inconnus acceptent `null` — un repas garde toujours
 * un nom, des calories et une heure. `components` : absent, la composition
 * reste ; vide, elle est retirée ; non vide, elle est remplacée.
 */
export interface MealPatch {
  name?: string;
  moment?: MealMoment | null;
  kcal?: number;
  quantity?: number | null;
  quantityUnit?: MealQuantityUnit | null;
  proteinG?: number | null;
  carbsG?: number | null;
  fatG?: number | null;
  eatenAt?: Date;
  components?: readonly ComponentRequest[];
}

/** La quantité stockée, ramenée au nombre que le reste du service manipule. */
export function quantityOf(meal: MealWithComponents): number | null {
  return meal.quantity === null ? null : meal.quantity.toNumber();
}

/** Les valeurs calculées que le repas porte, pour les comparer à une correction. */
export function computedValuesOf(meal: MealWithComponents): ComputedValues {
  return {
    kcal: meal.kcal,
    proteinG: meal.proteinG,
    carbsG: meal.carbsG,
    fatG: meal.fatG,
    quantity: quantityOf(meal),
    quantityUnit: meal.quantityUnit,
  };
}

/** Les totaux calculés, dans les colonnes du repas ; la quantité en grammes. */
export function computedColumns(totals: CompositionTotals) {
  return {
    kcal: totals.kcal,
    proteinG: totals.proteinG,
    carbsG: totals.carbsG,
    fatG: totals.fatG,
    quantity: totals.quantityG,
    quantityUnit: 'GRAM' as const,
  };
}

/**
 * Le fragment reçu traduit en écriture Prisma — les champs absents restent
 * absents, ce qui est exactement ce qui les laisse intacts en base.
 */
export function toUpdateData(patch: MealPatch): Prisma.MealEntryUpdateInput {
  const data: Prisma.MealEntryUpdateInput = {};
  if (patch.name !== undefined) data.name = patch.name;
  if (patch.moment !== undefined) data.moment = patch.moment;
  if (patch.kcal !== undefined) data.kcal = patch.kcal;
  if (patch.quantity !== undefined) data.quantity = patch.quantity;
  if (patch.quantityUnit !== undefined) data.quantityUnit = patch.quantityUnit;
  if (patch.proteinG !== undefined) data.proteinG = patch.proteinG;
  if (patch.carbsG !== undefined) data.carbsG = patch.carbsG;
  if (patch.fatG !== undefined) data.fatG = patch.fatG;
  if (patch.eatenAt !== undefined) data.eatenAt = patch.eatenAt;
  return data;
}

/**
 * Le fragment reçu réduit à ce qui DÉCRIT le repas (nom, moment, heure) :
 * ce qu'une correction écrit sur un repas composé dont elle garde la
 * composition. Ses totaux, calculés, ne se réécrivent pas.
 */
export function toDescriptiveUpdateData(patch: MealPatch): Prisma.MealEntryUpdateInput {
  return toUpdateData({ name: patch.name, moment: patch.moment, eatenAt: patch.eatenAt });
}
