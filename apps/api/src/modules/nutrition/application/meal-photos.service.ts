import { type MealEntry as MealEntryContract } from '@carlys/api-contracts';
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { type Prisma } from '@prisma/client';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { createHash } from 'node:crypto';
import {
  ConcurrentPhotoError,
  MealGoneError,
  MealPhotosRepository,
  type OwnedMeal,
} from '../infrastructure/meal-photos.repository';
import { MealPhotoObjects } from './meal-photo-objects';
import { acceptMealPhoto, type PhotoUpload } from './meal-photo-upload';
import { MealsService } from './meals.service';

const NO_PHOTO = 'Ce repas n’a pas de photo.';
const MEAL_NOT_FOUND = 'Repas introuvable.';

/** Ce que la lecture rend : les octets, et de quoi répondre 304. */
export interface MealPhotoContent {
  readonly bytes: Buffer;
  /** ETag FORT : l'empreinte SHA-256 des octets stockés, entre guillemets. */
  readonly etag: string;
  readonly updatedAt: Date;
}

/**
 * La photo qu'une personne joint à SON repas : déposer, relire, retirer.
 *
 * Donnée personnelle : elle n'est lue, remplacée ou retirée que par la
 * personne qui a enregistré le repas. Pour toute autre — repas inconnu,
 * supprimé ou d'autrui —, le MÊME 404 : un 403 confirmerait que
 * l'identifiant existe.
 *
 * L'ordre des écritures est choisi pour que rien ne se perde en silence :
 * l'objet NEUF part au stockage AVANT la ligne (une ligne sans objet serait
 * une photo morte) ; l'ANCIEN n'est effacé qu'APRÈS (un effacement raté
 * laisse un orphelin journalisé, jamais une photo perdue). Et la ligne ne
 * s'écrit qu'après avoir revérifié, sous verrou, que le repas et le compte
 * sont toujours là : l'envoi des octets laisse le temps de supprimer l'un
 * ou l'autre (`MealPhotosRepository.attach`).
 */
@Injectable()
export class MealPhotosService {
  constructor(
    private readonly photos: MealPhotosRepository,
    private readonly objects: MealPhotoObjects,
    private readonly meals: MealsService,
    @InjectPinoLogger(MealPhotosService.name) private readonly logger: PinoLogger,
  ) {}

  /** Pose ou remplace la photo ; rend le repas, `photo.updatedAt` compris. */
  async replace(
    userId: string,
    mealId: string,
    upload: PhotoUpload,
    requestId: string,
  ): Promise<MealEntryContract> {
    const meal = await this.owned(userId, mealId);
    const bytes = acceptMealPhoto(upload);
    const sha256 = createHash('sha256').update(bytes).digest('hex');
    // Rejeu du même envoi (la file hors ligne renvoie après une coupure) :
    // la photo est déjà celle-là, rien à déposer.
    if (meal.photo?.sha256 === sha256) {
      return this.meals.get(userId, mealId);
    }

    const storageKey = await this.objects.save(userId, bytes, requestId);
    const previous = meal.photo?.storageKey ?? null;
    const stored = { storageKey, byteSize: bytes.length, sha256 };
    try {
      await this.photos.attach(userId, mealId, previous, stored);
    } catch (error) {
      // L'objet neuf n'est cité par aucune ligne : on le reprend aussitôt.
      await this.objects.discard(storageKey, requestId);
      if (error instanceof MealGoneError) {
        // Supprimé pendant l'envoi : le même 404 qu'un repas inconnu.
        this.logger.info({ requestId, mealId }, 'Photo reçue pour un repas supprimé entre-temps');
        throw new NotFoundException(MEAL_NOT_FOUND);
      }
      if (error instanceof ConcurrentPhotoError) {
        throw new ConflictException(
          'La photo de ce repas vient de changer ailleurs : recharge le repas puis réessaie.',
        );
      }
      throw error;
    }
    if (previous !== null) {
      await this.objects.discard(previous, requestId);
    }
    return this.meals.get(userId, mealId);
  }

  async read(userId: string, mealId: string, requestId: string): Promise<MealPhotoContent> {
    const { photo } = await this.owned(userId, mealId);
    if (photo === null) {
      throw new NotFoundException(NO_PHOTO);
    }
    const bytes = await this.objects.read(photo.storageKey, requestId);
    if (bytes === null) {
      // La ligne cite un objet qui n'existe plus (base restaurée sans le
      // bucket, effacement à la main) : on la retire, pour que le repas
      // cesse d'annoncer une photo que personne ne pourra plus lire.
      this.logger.error(
        { requestId, mealId, storageKey: photo.storageKey },
        'Photo de repas introuvable dans le stockage : ligne retirée',
      );
      await this.photos.forgetMissingObject(mealId, photo.storageKey);
      throw new NotFoundException(NO_PHOTO);
    }
    return { bytes, etag: `"${photo.sha256}"`, updatedAt: photo.updatedAt };
  }

  /** Idempotent : un repas sans photo reste sans photo, et c'est un succès. */
  async remove(userId: string, mealId: string, requestId: string): Promise<void> {
    await this.owned(userId, mealId);
    const storageKey = await this.photos.detach(mealId);
    if (storageKey !== null) {
      await this.objects.discard(storageKey, requestId);
    }
  }

  /** Suppression du compte, DANS sa transaction : les lignes des photos. */
  forgetAllOf(userId: string, tx: Prisma.TransactionClient): Promise<void> {
    return this.photos.forgetAllOf(userId, tx);
  }

  /**
   * Suppression du compte, APRÈS sa transaction : tous ses objets, orphelins
   * compris. Ne lève jamais — un échec est journalisé avec le `requestId`.
   */
  eraseAllOf(userId: string, requestId: string | undefined): Promise<void> {
    return this.objects.discardAllOf(userId, requestId);
  }

  private async owned(userId: string, mealId: string): Promise<OwnedMeal> {
    const meal = await this.photos.findOwnedMeal(userId, mealId);
    if (meal === null) {
      throw new NotFoundException(MEAL_NOT_FOUND);
    }
    return meal;
  }
}
