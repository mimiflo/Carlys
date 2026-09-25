import { BadRequestException, Injectable } from '@nestjs/common';
import { type Food, type MealComponent, Prisma } from '@prisma/client';
import {
  MEAL_KCAL_MAX,
  MEAL_KCAL_MIN,
  MEAL_MACRO_MAX_G,
  MEAL_QUANTITY_MAX,
} from '../domain/meal-bounds';
import {
  type ComponentRow,
  type ComponentSnapshot,
  type CompositionTotals,
  compositionTotals,
} from '../domain/meal-composition';
import { type ComponentRequest } from '../domain/meal-write-rules';
import { FoodsRepository } from '../infrastructure/foods.repository';

export interface Composition {
  readonly rows: readonly ComponentRow[];
  readonly totals: CompositionTotals;
}

/** Les aliments de la base cités par une composition, par code, retirés compris. */
export type FoodCatalog = ReadonlyMap<number, Food>;

function snapshotOf(food: Food, quantityG: number): ComponentSnapshot {
  return {
    foodCode: food.code,
    foodName: food.name,
    foodShortName: food.shortName,
    foodGroup: food.groupName,
    foodSourceVersion: food.sourceVersion,
    kcalPer100g: food.kcalPer100g,
    proteinPer100g: food.proteinPer100g,
    carbsPer100g: food.carbsPer100g,
    fatPer100g: food.fatPer100g,
    quantityG: new Prisma.Decimal(quantityG),
  };
}

/** L'instantané d'une ligne DÉJÀ enregistrée, à sa nouvelle quantité. */
function keptSnapshot(stored: MealComponent, quantityG: number): ComponentSnapshot {
  return {
    foodCode: stored.foodCode,
    foodName: stored.foodName,
    foodShortName: stored.foodShortName,
    foodGroup: stored.foodGroup,
    foodSourceVersion: stored.foodSourceVersion,
    kcalPer100g: stored.kcalPer100g,
    proteinPer100g: stored.proteinPer100g,
    carbsPer100g: stored.carbsPer100g,
    fatPer100g: stored.fatPer100g,
    quantityG: new Prisma.Decimal(quantityG),
  };
}

const MACRO_LABELS = { proteinG: 'protéines', carbsG: 'glucides', fatG: 'lipides' } as const;

/**
 * Un total calculé hors des bornes d'un repas est refusé comme le serait la
 * même saisie à la main — avec un message qui dit quoi corriger, parce que
 * la personne n'a tapé que des grammes.
 */
function assertWithinMealBounds(totals: CompositionTotals): void {
  if (totals.kcal < MEAL_KCAL_MIN) {
    throw new BadRequestException(
      'Cette composition fait moins d’une kilocalorie : ajoute un aliment ou augmente les quantités.',
    );
  }
  if (totals.kcal > MEAL_KCAL_MAX) {
    throw new BadRequestException(
      `Cette composition dépasse ${MEAL_KCAL_MAX.toLocaleString('fr-FR')} kcal, la limite d’un repas : vérifie les quantités.`,
    );
  }
  for (const macro of ['proteinG', 'carbsG', 'fatG'] as const) {
    const grams = totals[macro];
    if (grams !== null && grams > MEAL_MACRO_MAX_G) {
      throw new BadRequestException(
        `Cette composition dépasse ${MEAL_MACRO_MAX_G.toLocaleString('fr-FR')} g de ${MACRO_LABELS[macro]}, la limite d’un repas : vérifie les quantités.`,
      );
    }
  }
  if (totals.quantityG.greaterThan(MEAL_QUANTITY_MAX)) {
    throw new BadRequestException(
      `Cette composition dépasse ${MEAL_QUANTITY_MAX.toLocaleString('fr-FR')} g au total : répartis-la en plusieurs repas.`,
    );
  }
}

/** Ce qui fait refuser une composition, rassemblé pour le dire en une fois. */
class Refusals {
  readonly unknown = new Set<number>();
  readonly retired = new Set<number>();
  readonly swapped: string[] = [];
  readonly duplicated: string[] = [];

  message(): string {
    const parts = [
      ...(this.unknown.size > 0 ? [`aliment inconnu : ${[...this.unknown].join(', ')}`] : []),
      ...(this.retired.size > 0
        ? [`aliment retiré de la base : ${[...this.retired].join(', ')}`]
        : []),
      ...this.swapped.map(
        (id) =>
          `la ligne ${id} désignait un autre aliment (changer d’aliment, c’est une ligne neuve, sous un nouvel identifiant)`,
      ),
      ...this.duplicated.map((id) => `identifiant de ligne en double : ${id}`),
    ];
    const pick = this.unknown.size + this.retired.size > 0 ? ' Choisis-en un autre.' : '';
    return `Composition refusée, ${parts.join(' ; ')}.${pick}`;
  }
}

/**
 * La composition CALCULÉE, sans lire la base : `catalog` porte les aliments
 * déjà lus, `stored` les lignes déjà enregistrées du repas (vide pour une
 * création).
 *
 * Une ligne dont l'`id` figure dans `stored` est GARDÉE : son instantané fait
 * foi (nom, valeurs pour 100 g, version de la table), seules sa quantité et
 * sa place changent. Même si l'aliment a quitté la base depuis : le retirer
 * du repas pour pouvoir corriger une autre ligne rendrait le journal faux. Et
 * une nouvelle version de la table ne recalcule pas en douce une ligne que la
 * personne n'a pas touchée.
 *
 * Une ligne à `id` NEUF lit `catalog` : un aliment inconnu ou retiré fait
 * refuser TOUTE la composition, en nommant les codes ; l'enregistrer sans lui
 * fausserait le total, le remplacer en silence ne serait pas moins faux.
 */
export function composeFrom(
  items: readonly ComponentRequest[],
  catalog: FoodCatalog,
  stored: readonly MealComponent[] = [],
): Composition {
  const kept = new Map(stored.map((component) => [component.id, component]));
  const refusals = new Refusals();
  const seen = new Set<string>();
  const rows: ComponentRow[] = [];
  items.forEach((item, position) => {
    if (seen.has(item.id)) {
      refusals.duplicated.push(item.id);
      return;
    }
    seen.add(item.id);
    const previous = kept.get(item.id);
    if (previous !== undefined) {
      if (previous.foodCode !== item.foodCode) {
        refusals.swapped.push(item.id);
        return;
      }
      const snapshot = keptSnapshot(previous, item.quantityG);
      rows.push({ id: item.id, position, createdAt: previous.createdAt, ...snapshot });
      return;
    }
    const food = catalog.get(item.foodCode);
    if (food === undefined) {
      refusals.unknown.add(item.foodCode);
    } else if (food.retiredAt !== null) {
      refusals.retired.add(item.foodCode);
    } else {
      rows.push({ id: item.id, position, ...snapshotOf(food, item.quantityG) });
    }
  });
  if (rows.length !== items.length) {
    throw new BadRequestException(refusals.message());
  }
  const totals = compositionTotals(rows);
  assertWithinMealBounds(totals);
  return { rows, totals };
}

/**
 * Transforme `[{ id, foodCode, quantityG }]` en composition CALCULÉE : lit la
 * base, prend l'instantané de chaque aliment, calcule les totaux.
 */
@Injectable()
export class MealComposer {
  constructor(private readonly foods: FoodsRepository) {}

  /** Les aliments cités, en UNE lecture (codes dédoublonnés), retirés compris. */
  async catalogFor(items: readonly ComponentRequest[]): Promise<FoodCatalog> {
    const codes = [...new Set(items.map((item) => item.foodCode))];
    const foods = await this.foods.findByCodes(codes);
    return new Map(foods.map((food) => [food.code, food]));
  }

  /** Une composition toute neuve (création) : chaque ligne lit la base. */
  async compose(items: readonly ComponentRequest[]): Promise<Composition> {
    return composeFrom(items, await this.catalogFor(items));
  }
}
