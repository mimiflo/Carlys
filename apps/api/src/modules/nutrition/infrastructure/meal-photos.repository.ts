import { Injectable } from '@nestjs/common';
import { type MealPhoto, Prisma, UserStatus } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

/**
 * La photo du repas a changé entre la lecture et l'écriture : un autre dépôt
 * (ou un retrait de la photo) est passé entre les deux.
 */
export class ConcurrentPhotoError extends Error {}

/**
 * Le repas n'est plus là pour recevoir la photo : supprimé, ou son compte
 * supprimé, pendant que les octets partaient au stockage.
 */
export class MealGoneError extends Error {}

/** Ce qu'on écrit d'un objet déposé. */
export interface StoredPhoto {
  readonly storageKey: string;
  readonly byteSize: number;
  readonly sha256: string;
}

/** Le repas VIVANT d'une personne, avec sa photo éventuelle. */
export interface OwnedMeal {
  readonly id: string;
  readonly photo: MealPhoto | null;
}

function isKnownError(error: unknown, code: string): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === code;
}

/** Les LIGNES `MealPhoto`. Les objets, eux, sont l'affaire de `MealPhotoObjects`. */
@Injectable()
export class MealPhotosRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Inconnu, supprimé ou d'autrui : `null`, sans dire lequel. */
  findOwnedMeal(userId: string, mealId: string): Promise<OwnedMeal | null> {
    return this.prisma.mealEntry.findFirst({
      where: { id: mealId, userId, deletedAt: null },
      select: { id: true, photo: true },
    });
  }

  /**
   * Pose `next` à la place de `previousKey` (`null` : le repas n'en avait
   * pas), en UNE transaction qui revérifie ce que le dépôt a lu avant
   * d'envoyer les octets au stockage, sous verrou :
   *
   *  1. le COMPTE, `FOR SHARE` : la suppression de compte commence par
   *     verrouiller cette ligne (`UsersRepository.deleteAccount`). Soit elle
   *     est passée, et le dépôt voit `DELETED` ; soit elle attend la fin de
   *     cette transaction, et efface alors la ligne écrite ici avec les
   *     autres. Sans ce verrou, une photo déposée pendant la suppression du
   *     compte survivait, citée par la ligne d'un repas vivant ;
   *  2. le REPAS, `FOR UPDATE` : la suppression douce met à jour cette même
   *     ligne. Soit elle est passée, et le dépôt voit `deletedAt` ; soit elle
   *     attend, puis trouve et retire la photo. Sans ce verrou, la ligne
   *     s'écrivait sous un repas déjà supprimé, sans que rien ne le dise ;
   *  3. la PHOTO en place : si elle n'est plus `previousKey`, un autre dépôt
   *     est passé entre-temps, `ConcurrentPhotoError`, et rien n'est écrit.
   *     Deux dépôts ne peuvent pas se croire tous deux gagnants et laisser un
   *     objet que plus rien ne cite.
   *
   * `MealGoneError` si le compte ou le repas n'est plus là : l'appelant
   * reprend l'objet qu'il vient de déposer.
   */
  async attach(
    userId: string,
    mealId: string,
    previousKey: string | null,
    next: StoredPhoto,
  ): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const [owner] = await tx.$queryRaw<{ status: UserStatus }[]>`
        SELECT "status" FROM "User" WHERE "id" = ${userId}::uuid FOR SHARE`;
      const [meal] = await tx.$queryRaw<{ userId: string; deletedAt: Date | null }[]>`
        SELECT "userId", "deletedAt" FROM "MealEntry" WHERE "id" = ${mealId}::uuid FOR UPDATE`;
      if (
        owner === undefined ||
        owner.status === UserStatus.DELETED ||
        meal === undefined ||
        meal.userId !== userId ||
        meal.deletedAt !== null
      ) {
        throw new MealGoneError();
      }
      const current = await tx.mealPhoto.findUnique({
        where: { mealId },
        select: { storageKey: true },
      });
      if ((current?.storageKey ?? null) !== previousKey) {
        throw new ConcurrentPhotoError();
      }
      await (current === null
        ? tx.mealPhoto.create({ data: { mealId, ...next } })
        : // `updatedAt` explicite : c'est la clé de cache du client, elle doit
          // bouger à chaque remplacement, quelle que soit la méthode d'écriture.
          tx.mealPhoto.update({ where: { mealId }, data: { ...next, updatedAt: new Date() } }));
    });
  }

  /** Retire la photo du repas ; rend la clé de l'objet à effacer, ou `null`. */
  async detach(mealId: string): Promise<string | null> {
    try {
      const removed = await this.prisma.mealPhoto.delete({
        where: { mealId },
        select: { storageKey: true },
      });
      return removed.storageKey;
    } catch (error) {
      // P2025 : plus de photo (déjà retirée, peut-être par une requête
      // concurrente) — le résultat voulu est atteint.
      if (isKnownError(error, 'P2025')) {
        return null;
      }
      throw error;
    }
  }

  /** Retire la ligne SI elle désigne encore cet objet (objet introuvable). */
  async forgetMissingObject(mealId: string, storageKey: string): Promise<void> {
    await this.prisma.mealPhoto.deleteMany({ where: { mealId, storageKey } });
  }

  /**
   * Suppression du compte : ses lignes partent dans SA transaction. Les
   * repas restent (historique anonyme), leurs photos non.
   */
  async forgetAllOf(userId: string, tx: Prisma.TransactionClient): Promise<void> {
    await tx.mealPhoto.deleteMany({ where: { meal: { userId } } });
  }
}
