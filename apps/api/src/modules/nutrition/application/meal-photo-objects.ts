import { MEAL_PHOTO_MIME_TYPE } from '@carlys/api-contracts';
import { Inject, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { randomUUID } from 'node:crypto';
import {
  deleteEverythingUnder,
  PRIVATE_OBJECT_STORE,
  type PrivateObjectStore,
} from '../../../infrastructure/storage/private-object-store';
import { mealPhotoKey, mealPhotoPrefixOf } from '../domain/meal-photo-key';

const UNAVAILABLE = 'Le stockage des photos ne répond pas : réessaie dans un instant.';

/**
 * Les OBJETS des photos de repas, dans le bucket privé.
 *
 * Seul endroit qui connaît leurs clés. Partagé par le journal (supprimer un
 * repas efface sa photo) et par les routes de la photo, sans que l'un
 * dépende de l'autre.
 *
 * LES EFFACEMENTS NE LÈVENT JAMAIS, ET NE SE TAISENT JAMAIS. Ils arrivent
 * APRÈS l'écriture en base qui a retiré la photo : échouer à ce moment-là
 * annoncerait l'échec d'une suppression qui a pourtant eu lieu. L'échec est
 * donc journalisé en ERREUR, avec le `requestId` et la clé ; l'objet, que
 * plus aucune ligne ne cite, est repris par le balayage des orphelins
 * (`dist/cli/meal-photos-sweep`, voir docs/product/nutrition.md).
 */
@Injectable()
export class MealPhotoObjects {
  constructor(
    @Inject(PRIVATE_OBJECT_STORE) private readonly objects: PrivateObjectStore,
    @InjectPinoLogger(MealPhotoObjects.name) private readonly logger: PinoLogger,
  ) {}

  /** Dépose des octets DÉJÀ filtrés sous une clé neuve, et la rend. */
  async save(userId: string, bytes: Buffer, requestId: string): Promise<string> {
    const key = mealPhotoKey(userId, randomUUID());
    try {
      await this.objects.put(key, bytes, MEAL_PHOTO_MIME_TYPE);
    } catch (error) {
      this.logger.error({ err: error, requestId }, 'Photo de repas non déposée');
      throw new ServiceUnavailableException(UNAVAILABLE);
    }
    return key;
  }

  /** Les octets, ou `null` si l'objet n'existe plus. */
  async read(key: string, requestId: string): Promise<Buffer | null> {
    try {
      return await this.objects.get(key);
    } catch (error) {
      this.logger.error({ err: error, requestId, storageKey: key }, 'Photo de repas illisible');
      throw new ServiceUnavailableException(UNAVAILABLE);
    }
  }

  /** Efface un objet ; un échec est journalisé, jamais levé. */
  async discard(key: string, requestId: string | undefined): Promise<void> {
    try {
      await this.objects.delete(key);
    } catch (error) {
      this.logger.error(
        { err: error, requestId, storageKey: key },
        'Photo de repas non effacée du stockage : objet orphelin, repris par meal-photos-sweep',
      );
    }
  }

  /**
   * Efface TOUTES les photos d'une personne, orphelins compris (tout son
   * préfixe). Un échec est journalisé, jamais levé.
   */
  async discardAllOf(userId: string, requestId: string | undefined): Promise<void> {
    try {
      const count = await deleteEverythingUnder(this.objects, mealPhotoPrefixOf(userId));
      this.logger.info({ requestId, count }, 'Photos de repas du compte effacées');
    } catch (error) {
      this.logger.error(
        { err: error, requestId, userId },
        'Photos de repas du compte NON effacées : reprises par meal-photos-sweep',
      );
    }
  }
}
