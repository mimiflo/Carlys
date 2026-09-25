import { MEAL_PHOTO_MAX_BYTES, MEAL_PHOTO_MIME_TYPE } from '@carlys/api-contracts';
import {
  BadRequestException,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import {
  type JpegRejection,
  JpegRejectedError,
  stripJpegMetadata,
} from '../../../common/images/jpeg-metadata';

/** Ce qui arrive du transport : le type DÉCLARÉ et les octets. */
export interface PhotoUpload {
  readonly mimeType: string;
  readonly content: Buffer;
}

export const MEAL_PHOTO_TOO_LARGE = 'Photo trop lourde : 5 Mo au plus.';

const REJECTIONS: Record<JpegRejection, string> = {
  'not-jpeg': 'Ce fichier n’est pas un JPEG : ses octets ne commencent pas par la signature JPEG.',
  malformed: 'JPEG illisible ou tronqué : renvoie la photo.',
  unsupported: 'Variante de JPEG non prise en charge : renvoie la photo en JPEG standard.',
};

/**
 * Accepte une photo de repas, ou lève le refus qui dit pourquoi. Rend les
 * octets À STOCKER : ceux du JPEG reçu, SANS ses métadonnées.
 *
 * Le type déclaré ne suffit pas : c'est le client qui l'écrit. Il doit dire
 * `image/jpeg` ET les octets doivent le prouver, par leur signature puis par
 * une structure que le filtre sait parcourir jusqu'à la fin d'image.
 */
export function acceptMealPhoto(upload: PhotoUpload): Buffer {
  if (upload.content.byteLength === 0) {
    throw new BadRequestException('Photo vide.');
  }
  if (upload.content.byteLength > MEAL_PHOTO_MAX_BYTES) {
    // Le transport coupe déjà à cette taille ; ceci garde le service juste
    // si on l'appelle un jour par un autre chemin.
    throw new PayloadTooLargeException(MEAL_PHOTO_TOO_LARGE);
  }
  if (upload.mimeType !== MEAL_PHOTO_MIME_TYPE) {
    throw new UnsupportedMediaTypeException(
      `Seul le JPEG est accepté (type déclaré : « ${upload.mimeType} »).`,
    );
  }
  try {
    return stripJpegMetadata(upload.content);
  } catch (error) {
    if (error instanceof JpegRejectedError) {
      throw new UnsupportedMediaTypeException(REJECTIONS[error.reason]);
    }
    throw error;
  }
}
