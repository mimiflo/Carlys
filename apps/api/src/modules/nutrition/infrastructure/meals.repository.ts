import { Injectable } from '@nestjs/common';
import { Prisma, type MealEntry, type MealQuantityUnit } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

@Injectable()
export class MealsRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Création idempotente : l'id vient de l'appareil, le rejeu est ignoré. */
  async create(input: {
    id: string;
    userId: string;
    name: string;
    kcal: number;
    quantity: number | null;
    quantityUnit: MealQuantityUnit | null;
    proteinG: number | null;
    carbsG: number | null;
    fatG: number | null;
    eatenAt: Date;
  }): Promise<void> {
    try {
      await this.prisma.mealEntry.create({ data: input });
    } catch (error) {
      // P2002 : identifiant déjà présent — rejeu d'une écriture passée.
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return;
      }
      throw error;
    }
  }

  findById(id: string): Promise<MealEntry | null> {
    return this.prisma.mealEntry.findUnique({ where: { id } });
  }

  /**
   * Plafond DUR du nombre de repas servis en une requête.
   *
   * Le service borne déjà l'amplitude de dates ; celui-ci borne le VOLUME,
   * qui n'en découle pas — rien n'interdit mille repas dans une seule
   * journée. Une requête sans `take` sur une table qui grossit avec l'usage
   * est un plafond implicite posé sur la mémoire du processus. Trente repas
   * par jour sur une année tiennent largement dessous.
   */
  private static readonly HARD_LIMIT = 10_000;

  listBetween(userId: string, from: Date, to: Date): Promise<MealEntry[]> {
    return this.prisma.mealEntry.findMany({
      where: { userId, deletedAt: null, eatenAt: { gte: from, lt: to } },
      orderBy: { eatenAt: 'asc' },
      take: MealsRepository.HARD_LIMIT,
    });
  }

  /**
   * Correction d'une entrée existante.
   *
   * `data` ne porte QUE les champs à changer : ce que le service a laissé de
   * côté n'apparaît pas dans l'objet, donc Prisma n'y touche pas. Un champ
   * présent à `null` efface, un champ absent conserve — c'est toute la
   * différence entre une correction et un écrasement.
   */
  update(id: string, data: Prisma.MealEntryUpdateInput): Promise<MealEntry> {
    return this.prisma.mealEntry.update({ where: { id }, data });
  }

  async softDelete(id: string): Promise<void> {
    await this.prisma.mealEntry.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }
}
