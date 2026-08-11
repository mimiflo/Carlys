import { Injectable } from '@nestjs/common';
import { Prisma, type MealEntry } from '@prisma/client';
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
    proteinG: number | null;
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

  listBetween(userId: string, from: Date, to: Date): Promise<MealEntry[]> {
    return this.prisma.mealEntry.findMany({
      where: { userId, deletedAt: null, eatenAt: { gte: from, lt: to } },
      orderBy: { eatenAt: 'asc' },
    });
  }

  async softDelete(id: string): Promise<void> {
    await this.prisma.mealEntry.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }
}
