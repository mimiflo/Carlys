import { Injectable } from '@nestjs/common';
import { type NotificationCategory } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

/**
 * Ce qu'une personne refuse de recevoir.
 *
 * **Absence de ligne = accepté.** Le stockage ne retient donc que les refus :
 * personne n'a besoin d'ouvrir les réglages pour que l'application se
 * comporte normalement, et une catégorie ajoutée plus tard n'arrive pas
 * coupée pour tout le monde.
 */
@Injectable()
export class NotificationPreferencesRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Les catégories explicitement REFUSÉES. */
  async disabledCategories(userId: string): Promise<Set<NotificationCategory>> {
    const rows = await this.prisma.notificationPreference.findMany({
      where: { userId, enabled: false },
      select: { category: true },
    });
    return new Set(rows.map((row) => row.category));
  }

  async isEnabled(userId: string, category: NotificationCategory): Promise<boolean> {
    const row = await this.prisma.notificationPreference.findUnique({
      where: { userId_category: { userId, category } },
      select: { enabled: true },
    });
    return row?.enabled ?? true;
  }

  /** Idempotent : régler deux fois la même valeur ne change rien. */
  async set(userId: string, category: NotificationCategory, enabled: boolean): Promise<void> {
    await this.prisma.notificationPreference.upsert({
      where: { userId_category: { userId, category } },
      create: { userId, category, enabled },
      update: { enabled },
    });
  }
}
