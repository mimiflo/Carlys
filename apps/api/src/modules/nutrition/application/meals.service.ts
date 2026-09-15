import { type MealEntry as MealEntryContract } from '@carlys/api-contracts';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { type MealEntry } from '@prisma/client';
import { MealsRepository } from '../infrastructure/meals.repository';

/**
 * L'amplitude maximale d'une demande de journal.
 *
 * Un an couvre largement ce que les écrans demandent — le jour courant, la
 * semaine, au plus un mois pour une courbe — tout en refusant la demande
 * dégénérée : deux dates éloignées d'une décennie, servies en une fois. Le
 * plafond de LIGNES (`MealsRepository.HARD_LIMIT`) ferme l'autre moitié de la
 * porte : une année chargée reste bornée en volume.
 */
const MAX_RANGE_DAYS = 366;
const MAX_RANGE_MS = MAX_RANGE_DAYS * 24 * 3_600_000;

function present(meal: MealEntry): MealEntryContract {
  return {
    id: meal.id,
    name: meal.name,
    kcal: meal.kcal,
    proteinG: meal.proteinG,
    carbsG: meal.carbsG,
    fatG: meal.fatG,
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
      carbsG: number | null;
      fatG: number | null;
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

  /**
   * Repas entre deux instants (bornes du jour local, calculées au client).
   *
   * La plage est BORNÉE, et la requête plafonnée. C'était la seule collection
   * du dépôt sans plafond : toutes les autres portent un `limit` validé
   * (`@Max(MAX_PAGE_SIZE)` pour les séances et les modèles, `@Max(365)` pour
   * les mesures corporelles, `@Max(200)` pour l'audit). Ici, deux dates
   * suffisaient à demander des années de journal en une requête, et le dépôt
   * servait tout. L'écran, lui, ne demande jamais qu'un jour ou une semaine.
   */
  async list(userId: string, from: Date, to: Date): Promise<MealEntryContract[]> {
    if (to.getTime() <= from.getTime()) {
      throw new BadRequestException('La borne haute doit suivre la borne basse.');
    }
    if (to.getTime() - from.getTime() > MAX_RANGE_MS) {
      throw new BadRequestException(
        `La plage demandée dépasse ${MAX_RANGE_DAYS} jours — découper la demande.`,
      );
    }
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
