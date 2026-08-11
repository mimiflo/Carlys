import { type MealEntry as MealEntryContract } from '@carlys/api-contracts';
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { type MealEntry } from '@prisma/client';
import { MealsRepository } from '../infrastructure/meals.repository';

function present(meal: MealEntry): MealEntryContract {
  return {
    id: meal.id,
    name: meal.name,
    kcal: meal.kcal,
    proteinG: meal.proteinG,
    eatenAt: meal.eatenAt.toISOString(),
  };
}

/**
 * Journal alimentaire — la moitié RÉELLE du « consommé / objectif ».
 *
 * Mêmes règles que les séances : identifiant généré sur l'appareil (création
 * idempotente, rejouable), suppression douce idempotente, et des INSTANTS
 * UTC — le découpage en journées appartient au client, qui connaît son
 * fuseau ; le serveur ne devine jamais où commence « aujourd'hui ».
 */
@Injectable()
export class MealsService {
  constructor(private readonly meals: MealsRepository) {}

  /** Création idempotente : rejouer la même écriture rend la même entrée. */
  async add(
    userId: string,
    input: {
      id: string;
      name: string;
      kcal: number;
      proteinG: number | null;
      eatenAt: Date;
    },
  ): Promise<MealEntryContract> {
    await this.meals.create({ userId, ...input });
    const stored = await this.meals.findById(input.id);
    if (stored === null || stored.userId !== userId) {
      // L'identifiant existe déjà chez QUELQU'UN D'AUTRE : collision réelle.
      throw new ConflictException('Identifiant de repas déjà utilisé.');
    }
    return present(stored);
  }

  /** Repas entre deux instants (bornes du jour local, calculées au client). */
  async list(userId: string, from: Date, to: Date): Promise<MealEntryContract[]> {
    const meals = await this.meals.listBetween(userId, from, to);
    return meals.map(present);
  }

  /** Idempotent : supprimer un repas déjà supprimé ou inconnu aboutit. */
  async remove(userId: string, id: string): Promise<void> {
    const meal = await this.meals.findById(id);
    if (meal === null || meal.deletedAt !== null) {
      return;
    }
    if (meal.userId !== userId) {
      // Même réponse qu'un 404 : ne pas révéler l'existence d'autrui.
      throw new NotFoundException('Repas introuvable.');
    }
    await this.meals.softDelete(id);
  }
}
