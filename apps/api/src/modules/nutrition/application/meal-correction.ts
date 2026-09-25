import { BadRequestException, NotFoundException } from '@nestjs/common';
import {
  type CompositionChange,
  computedFieldsChanged,
  patchConflict,
} from '../domain/meal-write-rules';
import { type MealWithComponents, type MealWrite } from '../infrastructure/meals.repository';
import { composeFrom, type FoodCatalog } from './meal-composer';
import {
  assertPairedQuantity,
  computedColumns,
  computedValuesOf,
  type MealPatch,
  quantityOf,
  toDescriptiveUpdateData,
  toUpdateData,
} from './meal-writes';

export const MEAL_NOT_FOUND = 'Repas introuvable.';

export interface CorrectionInput {
  readonly userId: string;
  /** Le repas relu SOUS VERROU : c'est sur lui, et lui seul, que tout se juge. */
  readonly current: MealWithComponents;
  readonly patch: MealPatch;
  readonly change: CompositionChange;
  /** Les aliments de la base cités par `change`, lus avant le verrou. */
  readonly catalog: FoodCatalog;
}

/**
 * Ce qu'une correction écrit, décidé sur l'état lu sous le verrou de la
 * ligne (`MealsRepository.correct`). Sans effet de bord : rend l'écriture,
 * ou lève l'erreur HTTP à opposer, et la transaction n'écrit alors rien.
 *
 * Trois cas :
 *  - composition REMPLACÉE : les lignes désignées par leur identifiant
 *    gardent leur instantané, les neuves lisent la base, tout se recalcule ;
 *  - composition GARDÉE d'un repas composé : seuls le nom, le moment et
 *    l'heure s'écrivent ; un total renvoyé À L'IDENTIQUE n'est pas une
 *    correction, un total CHANGÉ est refusé ;
 *  - repas saisi à la main, ou composition retirée : les totaux se
 *    corrigent, la paire quantité / unité se juge sur l'état APRÈS
 *    correction.
 */
export function planCorrection({
  userId,
  current,
  patch,
  change,
  catalog,
}: CorrectionInput): MealWrite {
  if (current.userId !== userId || current.deletedAt !== null) {
    // Inconnu, supprimé ou d'autrui : le même 404, qui ne dit pas lequel.
    throw new NotFoundException(MEAL_NOT_FOUND);
  }
  if (change.kind === 'replace') {
    const composition = composeFrom(change.items, catalog, current.components);
    return {
      data: { ...toUpdateData(patch), ...computedColumns(composition.totals) },
      components: composition.rows,
    };
  }
  if (change.kind === 'keep' && current.components.length > 0) {
    const changed = computedFieldsChanged(patch, computedValuesOf(current));
    const conflict = patchConflict(change, changed, true);
    if (conflict !== null) {
      throw new BadRequestException(conflict);
    }
    return { data: toDescriptiveUpdateData(patch) };
  }
  // La cohérence se juge sur l'état APRÈS correction, pas sur le seul
  // fragment reçu : effacer l'unité sans toucher au nombre laisserait
  // « 250 » tout seul, ce qu'aucun écran ne sait afficher.
  assertPairedQuantity(
    patch.quantity !== undefined ? patch.quantity : quantityOf(current),
    patch.quantityUnit !== undefined ? patch.quantityUnit : current.quantityUnit,
  );
  return change.kind === 'clear'
    ? { data: toUpdateData(patch), components: [] }
    : { data: toUpdateData(patch) };
}
