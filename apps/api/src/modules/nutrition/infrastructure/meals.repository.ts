import { Injectable } from '@nestjs/common';
import { Prisma, type MealMoment, type MealQuantityUnit } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { type ComponentRow } from '../domain/meal-composition';

/**
 * Les composants suivent TOUJOURS leur repas, dans l'ordre d'affichage ; la
 * photo aussi, réduite à ce que le client lit (`updatedAt`).
 */
const WITH_COMPONENTS = {
  components: { orderBy: { position: 'asc' } },
  photo: { select: { updatedAt: true } },
} satisfies Prisma.MealEntryInclude;

export type MealWithComponents = Prisma.MealEntryGetPayload<{ include: typeof WITH_COMPONENTS }>;

/**
 * Une ligne de composition porte un identifiant (UUID de l'appareil) que
 * possède déjà la ligne d'un AUTRE repas. Les corrections d'un même repas se
 * sérialisent sous le verrou de sa ligne (`correct`) : le conflit ne peut
 * venir que de là.
 */
export class ComponentIdTakenError extends Error {}

/**
 * Ce qu'une correction écrit. `components` absent : la composition ne bouge
 * pas ; présent (vide compris) : il REMPLACE toute la liste.
 */
export interface MealWrite {
  readonly data: Prisma.MealEntryUpdateInput;
  readonly components?: readonly ComponentRow[];
}

export interface MealCreate {
  readonly id: string;
  readonly userId: string;
  readonly name: string;
  readonly moment: MealMoment | null;
  readonly kcal: number;
  readonly quantity: Prisma.Decimal | number | null;
  readonly quantityUnit: MealQuantityUnit | null;
  readonly proteinG: number | null;
  readonly carbsG: number | null;
  readonly fatG: number | null;
  readonly eatenAt: Date;
}

function componentData(row: ComponentRow): Prisma.MealComponentCreateManyMealInput {
  return {
    id: row.id,
    position: row.position,
    foodCode: row.foodCode,
    quantityG: row.quantityG,
    foodName: row.foodName,
    foodShortName: row.foodShortName,
    foodGroup: row.foodGroup,
    foodSourceVersion: row.foodSourceVersion,
    kcalPer100g: row.kcalPer100g,
    proteinPer100g: row.proteinPer100g,
    carbsPer100g: row.carbsPer100g,
    fatPer100g: row.fatPer100g,
    createdAt: row.createdAt,
  };
}

function isUniqueViolation(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
}

@Injectable()
export class MealsRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Création idempotente : l'id vient de l'appareil, le rejeu est ignoré.
   * Le repas et ses composants partent dans la MÊME instruction : un rejeu
   * ne peut donc pas laisser un repas sans ses aliments, ni l'inverse.
   */
  async create(input: MealCreate, components: readonly ComponentRow[]): Promise<void> {
    try {
      await this.prisma.mealEntry.create({
        data: {
          ...input,
          ...(components.length > 0
            ? { components: { createMany: { data: components.map(componentData) } } }
            : {}),
        },
      });
    } catch (error) {
      // P2002 : identifiant déjà présent — rejeu d'une écriture passée.
      if (isUniqueViolation(error)) {
        return;
      }
      throw error;
    }
  }

  findById(id: string): Promise<MealWithComponents | null> {
    return this.prisma.mealEntry.findUnique({ where: { id }, include: WITH_COMPONENTS });
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

  listBetween(userId: string, from: Date, to: Date): Promise<MealWithComponents[]> {
    return this.prisma.mealEntry.findMany({
      where: { userId, deletedAt: null, eatenAt: { gte: from, lt: to } },
      orderBy: { eatenAt: 'asc' },
      take: MealsRepository.HARD_LIMIT,
      include: WITH_COMPONENTS,
    });
  }

  /**
   * Correction d'une entrée existante, décidée ET écrite sous le verrou de
   * sa ligne.
   *
   * `decide` reçoit l'état relu APRÈS le verrou (`SELECT … FOR UPDATE`), et
   * rend l'écriture à faire, ou lève l'erreur à opposer : la transaction est
   * alors annulée sans rien écrire. Une décision prise sur une lecture faite
   * AVANT le verrou pouvait être périmée au moment d'écrire : une correction
   * manuelle lisait un repas sans aliments, une recomposition passait, puis
   * la correction écrivait ses calories par-dessus un total calculé. Toute
   * écriture concurrente du repas (correction, suppression douce, photo)
   * prend le même verrou : elles passent l'une après l'autre, chacune sur
   * l'état laissé par la précédente.
   *
   * `data` ne porte QUE les champs à changer : un champ présent à `null`
   * efface, un champ absent conserve. `null` en retour : repas inconnu.
   */
  async correct(
    id: string,
    decide: (current: MealWithComponents) => MealWrite,
  ): Promise<MealWithComponents | null> {
    try {
      return await this.prisma.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT 1 FROM "MealEntry" WHERE "id" = ${id}::uuid FOR UPDATE`;
        const current = await tx.mealEntry.findUnique({ where: { id }, include: WITH_COMPONENTS });
        if (current === null) {
          return null;
        }
        const write = decide(current);
        if (write.components !== undefined) {
          await tx.mealComponent.deleteMany({ where: { mealId: id } });
          if (write.components.length > 0) {
            await tx.mealComponent.createMany({
              data: write.components.map((row) => ({ ...componentData(row), mealId: id })),
            });
          }
        }
        return tx.mealEntry.update({ where: { id }, data: write.data, include: WITH_COMPONENTS });
      });
    } catch (error) {
      if (isUniqueViolation(error)) {
        throw new ComponentIdTakenError();
      }
      throw error;
    }
  }

  /**
   * Suppression douce. La LIGNE de la photo part dans la même transaction :
   * un repas supprimé n'a plus de photo, en base, dès cet instant. Rend la
   * clé de l'objet à effacer du stockage (ce qui se fait APRÈS, hors
   * transaction : S3 n'en connaît pas), ou `null` sans photo.
   */
  async softDelete(id: string): Promise<string | null> {
    return this.prisma.$transaction(async (tx) => {
      await tx.mealEntry.update({ where: { id }, data: { deletedAt: new Date() } });
      const photo = await tx.mealPhoto.findUnique({
        where: { mealId: id },
        select: { storageKey: true },
      });
      if (photo !== null) {
        await tx.mealPhoto.delete({ where: { mealId: id } });
      }
      return photo?.storageKey ?? null;
    });
  }
}
