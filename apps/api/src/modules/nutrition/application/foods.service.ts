import { type Food as FoodContract, type FoodSource } from '@carlys/api-contracts';
import { Injectable, NotFoundException } from '@nestjs/common';
import { type Prisma } from '@prisma/client';
import { ciqualAttribution } from '../domain/ciqual-source';
import { searchWords } from '../domain/food-text';
import { FOOD_CODE_MAX } from '../domain/meal-bounds';
import { FoodsRepository, type FoodSearchRow } from '../infrastructure/foods.repository';

function asNumber(value: Prisma.Decimal | null): number | null {
  return value === null ? null : value.toNumber();
}

/** Un aliment tel que le client le lit (valeurs pour 100 g). */
export function presentFood(food: FoodSearchRow): FoodContract {
  return {
    code: food.code,
    name: food.name,
    shortName: food.shortName,
    group: food.groupName,
    per100g: {
      kcal: food.kcalPer100g.toNumber(),
      proteinG: asNumber(food.proteinPer100g),
      carbsG: asNumber(food.carbsPer100g),
      fatG: asNumber(food.fatPer100g),
    },
  };
}

/**
 * La base d'aliments, en lecture : recherche et fiche.
 *
 * Chaque réponse porte la mention de source (`ciqualAttribution`) et la
 * version chargée : la licence exige l'une et l'autre là où les valeurs
 * sont montrées.
 */
@Injectable()
export class FoodsService {
  constructor(private readonly foods: FoodsRepository) {}

  async source(): Promise<FoodSource> {
    return { ...ciqualAttribution(), version: await this.foods.currentVersion() };
  }

  /**
   * Une saisie sans lettre ni chiffre (« !! ») ne cherche rien et ne trouve
   * rien : une liste vide, pas une erreur — l'écran interroge à chaque
   * frappe, et « aucun résultat » est la réponse juste.
   */
  async search(
    query: string,
    limit: number,
  ): Promise<{ items: FoodContract[]; source: FoodSource }> {
    const [first, ...others] = searchWords(query);
    const rows = first === undefined ? [] : await this.foods.search([first, ...others], limit);
    return { items: rows.map(presentFood), source: await this.source() };
  }

  /**
   * La fiche d'un aliment. Retiré ou inconnu : 404 dans les deux cas — un
   * aliment retiré ne peut plus entrer dans un repas, le montrer comme
   * disponible inviterait à un 400 au moment d'enregistrer.
   */
  async detail(code: number): Promise<{ food: FoodContract; source: FoodSource }> {
    // Hors de la colonne (`Int` PostgreSQL) : Prisma lèverait une erreur de
    // validation, servie en 500, pour ce qui n'est qu'un code inconnu.
    const food = code >= 1 && code <= FOOD_CODE_MAX ? await this.foods.findByCode(code) : null;
    if (food === null || food.retiredAt !== null) {
      throw new NotFoundException('Aliment introuvable.');
    }
    return { food: presentFood(food), source: await this.source() };
  }
}
