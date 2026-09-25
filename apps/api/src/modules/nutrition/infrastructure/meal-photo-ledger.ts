import { type PrismaClient, UserStatus } from '@prisma/client';

/**
 * Le registre des photos vu par le balayage des orphelins.
 *
 * Construit sur un `PrismaClient` nu, et non sur `PrismaService` : la
 * commande `meal-photos-sweep` tourne hors de Nest, comme les autres
 * commandes de l'image (`catalog-seed`, `ciqual-import`).
 */
export class MealPhotoLedger {
  constructor(private readonly prisma: PrismaClient) {}

  /**
   * Parmi ces clés, celles d'une photo VIVANTE : citée par la ligne d'un
   * repas qui n'est pas supprimé, d'un compte qui ne l'est pas non plus.
   * Tout le reste est orphelin. La suppression d'un compte retire déjà ses
   * lignes, dans sa transaction ; ce second critère est le filet d'une ligne
   * qui y aurait échappé, pour qu'elle ne rende pas son objet éternel.
   */
  async liveKeysAmong(keys: readonly string[]): Promise<Set<string>> {
    if (keys.length === 0) {
      return new Set();
    }
    const rows = await this.prisma.mealPhoto.findMany({
      where: {
        storageKey: { in: [...keys] },
        meal: { deletedAt: null, user: { status: { not: UserStatus.DELETED } } },
      },
      select: { storageKey: true },
    });
    return new Set(rows.map((row) => row.storageKey));
  }

  /**
   * Retire les lignes restées sous un repas ou un compte supprimé, une fois
   * leur objet effacé.
   */
  async forgetKeys(keys: readonly string[]): Promise<void> {
    if (keys.length > 0) {
      await this.prisma.mealPhoto.deleteMany({ where: { storageKey: { in: [...keys] } } });
    }
  }
}
