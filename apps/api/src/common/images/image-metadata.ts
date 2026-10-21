import { JpegRejectedError, stripJpegMetadata } from './jpeg-metadata';

/**
 * Retire les métadonnées d'une image (JPEG, PNG, WebP) sans la décoder.
 *
 * Même principe que `jpeg-metadata.ts`, auquel le JPEG est confié : ces trois
 * formats sont des suites de blocs à longueur annoncée, et les métadonnées
 * (EXIF et sa position GPS, XMP, textes libres, dates) vivent dans des blocs
 * À PART des pixels. Les retirer, c'est recopier les autres : aucun pixel
 * réencodé, aucune dépendance de traitement d'image.
 *
 * LISTE BLANCHE, PAS LISTE NOIRE : on garde ce qui sert à AFFICHER l'image,
 * et le profil de couleur. Ce qui n'est pas lisible jusqu'au bout est
 * REFUSÉ, jamais recopié à l'aveugle. Un autre format (l'AVIF, dont l'EXIF
 * est un « item » référencé par des décalages qu'il faudrait réécrire) est
 * refusé : on ne publie que ce qu'on sait nettoyer.
 */
export class ImageRejectedError extends Error {
  constructor(detail: string) {
    super(detail);
    this.name = 'ImageRejectedError';
  }
}

export function stripImageMetadata(mimeType: string, bytes: Buffer): Buffer {
  switch (mimeType) {
    case 'image/jpeg':
      try {
        return stripJpegMetadata(bytes);
      } catch (error) {
        if (error instanceof JpegRejectedError) throw new ImageRejectedError(error.message);
        throw error;
      }
    case 'image/png':
      return stripPng(bytes);
    case 'image/webp':
      return stripWebp(bytes);
    default:
      throw new ImageRejectedError(`Type d'image sans nettoyage des métadonnées : ${mimeType}.`);
  }
}

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

/**
 * Chunks PNG gardés : les critiques, la transparence, le rendu des couleurs
 * (gamma, primaires, profil ICC, HDR), la densité, et l'animation (APNG).
 * Partent : eXIf, tEXt, zTXt, iTXt (où vit le XMP), tIME, et tout inconnu
 * ANCILLAIRE. Un critique inconnu (majuscule initiale) fait refuser : sans
 * lui, l'image ne s'afficherait pas comme prévu.
 */
const PNG_KEPT = new Set([
  'IHDR', 'PLTE', 'IDAT', 'IEND', 'tRNS', 'gAMA', 'cHRM', 'sRGB', 'iCCP', 'sBIT',
  'cICP', 'mDCV', 'cLLI', 'bKGD', 'pHYs', 'acTL', 'fcTL', 'fdAT',
]); // prettier-ignore

function stripPng(bytes: Buffer): Buffer {
  if (!bytes.subarray(0, 8).equals(PNG_SIGNATURE)) {
    throw new ImageRejectedError('Les octets ne commencent pas par une signature PNG.');
  }
  const kept: Buffer[] = [PNG_SIGNATURE];
  let position = 8;
  while (position + 12 <= bytes.length) {
    const end = position + 12 + bytes.readUInt32BE(position);
    const type = bytes.toString('latin1', position + 4, position + 8);
    if (end > bytes.length || (position === 8 && type !== 'IHDR')) break;
    if (PNG_KEPT.has(type)) {
      kept.push(bytes.subarray(position, end));
    } else if (/^[A-Z]/.test(type)) {
      throw new ImageRejectedError(`Chunk PNG critique non pris en charge : ${type}.`);
    }
    // Tout ce qui suit IEND est ignoré par les décodeurs, donc retiré. Sans
    // IDAT, aucun pixel : un fichier qui n'est pas une image.
    if (type === 'IEND') {
      if (!kept.some((chunk) => chunk.toString('latin1', 4, 8) === 'IDAT')) break;
      return Buffer.concat(kept);
    }
    position = end;
  }
  throw new ImageRejectedError('PNG illisible ou tronqué.');
}

/** Drapeaux EXIF (0x08) et XMP (0x04) de l'en-tête étendu VP8X. */
const VP8X_METADATA_FLAGS = 0x08 | 0x04;
/** Chunks WebP gardés ; EXIF, XMP et tout inconnu partent. */
/** Ceux qui portent les pixels : sans l'un d'eux, ce n'est pas une image. */
const WEBP_IMAGE = new Set(['VP8 ', 'VP8L', 'ANMF']);
const WEBP_KEPT = new Set(['VP8 ', 'VP8L', 'VP8X', 'ALPH', 'ANIM', 'ANMF', 'ICCP']);

function stripWebp(bytes: Buffer): Buffer {
  if (
    bytes.length < 12 ||
    bytes.toString('latin1', 0, 4) !== 'RIFF' ||
    bytes.toString('latin1', 8, 12) !== 'WEBP'
  ) {
    throw new ImageRejectedError('Les octets ne commencent pas par un en-tête WebP.');
  }
  const riffEnd = 8 + bytes.readUInt32LE(4);
  if (riffEnd > bytes.length) {
    throw new ImageRejectedError('WebP tronqué : la taille annoncée dépasse le fichier.');
  }
  const kept: Buffer[] = [];
  let position = 12;
  while (position < riffEnd) {
    if (position + 8 > riffEnd) throw new ImageRejectedError('WebP illisible : chunk tronqué.');
    const size = bytes.readUInt32LE(position + 4);
    const end = position + 8 + size + (size % 2);
    if (end > riffEnd) throw new ImageRejectedError('WebP illisible : chunk tronqué.');
    const fourcc = bytes.toString('latin1', position, position + 4);
    if (fourcc === 'VP8X' && (position !== 12 || size < 10)) {
      throw new ImageRejectedError('WebP illisible : en-tête VP8X mal placé ou tronqué.');
    }
    if (fourcc === 'VP8X') {
      const chunk = Buffer.from(bytes.subarray(position, end));
      chunk[8] = chunk[8]! & ~VP8X_METADATA_FLAGS;
      kept.push(chunk);
    } else if (WEBP_KEPT.has(fourcc)) {
      kept.push(bytes.subarray(position, end));
    }
    position = end;
  }
  if (!kept.some((chunk) => WEBP_IMAGE.has(chunk.toString('latin1', 0, 4)))) {
    throw new ImageRejectedError('WebP sans image : ni VP8, ni VP8L, ni ANMF.');
  }
  // Ce qui suit la fin annoncée du RIFF n'est pas lu : il part aussi.
  const body = Buffer.concat([Buffer.from('WEBP', 'latin1'), ...kept]);
  const header = Buffer.alloc(8);
  header.write('RIFF', 0, 'latin1');
  header.writeUInt32LE(body.length, 4);
  return Buffer.concat([header, body]);
}
