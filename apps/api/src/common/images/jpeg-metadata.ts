/**
 * Retire les métadonnées d'un JPEG, sans le décoder.
 *
 * POURQUOI À LA MAIN. Un JPEG est une suite de segments `FF xx` à longueur
 * annoncée ; les métadonnées (EXIF et sa position GPS, XMP, IPTC,
 * commentaires) vivent dans des segments À PART de l'image. Les retirer, c'est
 * recopier les autres : aucun pixel n'est décodé ni réencodé, donc aucune
 * perte de qualité, et aucune dépendance de traitement d'image (sharp embarque
 * libvips, plusieurs dizaines de mégaoctets de code natif, pour un tri de
 * segments). Même choix que `readImageSize` dans le module des médias.
 *
 * LISTE BLANCHE, PAS LISTE NOIRE. On garde ce qui sert à DÉCODER l'image
 * (trames, tables de quantification et de Huffman, balayages) et trois
 * segments d'application vérifiés un par un :
 *
 * - APP0 « JFIF », RÉÉCRIT sans sa vignette : une vignette est une seconde
 *   image, et celle d'une photo recadrée montre ce que le recadrage cachait ;
 * - APP2 « ICC_PROFILE » : le profil de couleur, sans lequel une photo prise
 *   en Display P3 s'affiche délavée. (Les autres APP2, MPF et FlashPix,
 *   partent : MPF désigne justement des images cachées en fin de fichier.)
 * - APP14 « Adobe », à sa taille exacte de douze octets et à elle seule :
 *   c'est un paramètre de décodage (transformée de couleur), pas une
 *   métadonnée. L'ôter changerait les couleurs d'un JPEG RVB ou CMJN. À cette
 *   taille, il ne peut rien porter d'autre.
 *
 * Tout le reste des APP1 à APP15 part (EXIF, XMP, IPTC dans APP13…), ainsi
 * que les commentaires (COM) et TOUT octet après la fin d'image (EOI), où
 * certains appareils rangent un second JPEG avec son propre EXIF. Un marqueur
 * inconnu ou réservé fait REFUSER le fichier plutôt que de le recopier à
 * l'aveugle : on ne stocke que ce qu'on sait lire.
 *
 * CONSÉQUENCE À CONNAÎTRE CÔTÉ CLIENT : l'orientation EXIF part avec le
 * reste. Le client doit redresser les pixels AVANT l'envoi (c'est ce que font
 * les compresseurs d'image mobiles par défaut), sinon une photo prise en
 * portrait s'affichera couchée.
 */

const SOI = 0xd8;
const EOI = 0xd9;
const SOS = 0xda;
const APP0 = 0xe0;
const APP2 = 0xe2;
const APP14 = 0xee;
const COM = 0xfe;

/** Ce qui fait refuser un fichier : jamais « on stocke quand même ». */
export type JpegRejection = 'not-jpeg' | 'malformed' | 'unsupported';

export class JpegRejectedError extends Error {
  constructor(
    readonly reason: JpegRejection,
    detail: string,
  ) {
    super(detail);
    this.name = 'JpegRejectedError';
  }
}

/** Les trois premiers octets de tout JPEG : SOI puis le début d'un marqueur. */
export function hasJpegSignature(bytes: Buffer): boolean {
  return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === SOI && bytes[2] === 0xff;
}

/** Marqueurs STRUCTURELS : sans eux, l'image ne se décode pas. */
function isStructural(marker: number): boolean {
  // C0…CF : trames (SOFn), tables de Huffman (C4) et de codage arithmétique
  // (CC) — sauf C8, réservé aux extensions JPEG.
  if (marker >= 0xc0 && marker <= 0xcf) {
    return marker !== 0xc8;
  }
  // DQT, DNL, DRI, DHP, EXP.
  return (
    marker === 0xdb || marker === 0xdc || marker === 0xdd || marker === 0xde || marker === 0xdf
  );
}

function isStartOfFrame(marker: number): boolean {
  return isStructural(marker) && marker <= 0xcf && marker !== 0xc4 && marker !== 0xcc;
}

function startsWith(payload: Buffer, signature: string): boolean {
  return payload.subarray(0, signature.length).equals(Buffer.from(signature, 'latin1'));
}

function segment(marker: number, payload: Buffer): Buffer {
  const header = Buffer.alloc(4);
  header[0] = 0xff;
  header[1] = marker;
  header.writeUInt16BE(payload.length + 2, 2);
  return Buffer.concat([header, payload]);
}

/**
 * Un segment d'application : gardé (éventuellement réécrit), ou `null` pour
 * le retirer.
 */
function applicationSegment(marker: number, payload: Buffer): Buffer | null {
  if (marker === APP0 && startsWith(payload, 'JFIF\0') && payload.length >= 14) {
    // Identifiant (5), version (2), unité (1), densités (2 + 2), puis la
    // taille de la vignette (1 + 1) et ses pixels : remise à zéro.
    const jfif = Buffer.from(payload.subarray(0, 14));
    jfif[12] = 0;
    jfif[13] = 0;
    return segment(marker, jfif);
  }
  if (marker === APP2 && startsWith(payload, 'ICC_PROFILE\0')) {
    return segment(marker, payload);
  }
  if (marker === APP14 && payload.length === 12 && startsWith(payload, 'Adobe')) {
    return segment(marker, payload);
  }
  return null;
}

/**
 * La fin des données compressées d'un balayage : le premier marqueur qui
 * n'est ni un octet bourré (`FF 00`) ni une remise à zéro (`FF D0`…`FF D7`).
 */
function endOfEntropyData(bytes: Buffer, from: number): number {
  let index = from;
  for (;;) {
    index = bytes.indexOf(0xff, index);
    if (index < 0 || index + 1 >= bytes.length) {
      throw new JpegRejectedError('malformed', 'Balayage sans fin : fichier tronqué.');
    }
    const next = bytes[index + 1]!;
    if (next !== 0x00 && (next < 0xd0 || next > 0xd7)) {
      // Un vrai marqueur (ou ses octets de remplissage `FF FF…`) : il
      // commence ici, et la boucle principale saute le remplissage.
      return index;
    }
    index += 2;
  }
}

/** Rend le JPEG sans ses métadonnées, ou lève `JpegRejectedError`. */
export function stripJpegMetadata(input: Buffer): Buffer {
  if (!hasJpegSignature(input)) {
    throw new JpegRejectedError('not-jpeg', 'Les octets ne commencent pas par une signature JPEG.');
  }
  const kept: Buffer[] = [Buffer.from([0xff, SOI])];
  let position = 2;
  let sawFrame = false;
  let sawScan = false;

  for (;;) {
    if (position >= input.length || input[position] !== 0xff) {
      throw new JpegRejectedError('malformed', 'Marqueur attendu, octets inattendus.');
    }
    while (position < input.length && input[position] === 0xff) {
      position += 1;
    }
    if (position >= input.length) {
      throw new JpegRejectedError('malformed', 'Fichier tronqué avant la fin d’image.');
    }
    const marker = input[position]!;
    position += 1;

    if (marker === EOI) {
      if (!sawFrame || !sawScan) {
        throw new JpegRejectedError('malformed', 'Fin d’image sans trame ni balayage.');
      }
      kept.push(Buffer.from([0xff, EOI]));
      // Tout ce qui suit la fin d'image est ignoré, donc retiré.
      return Buffer.concat(kept);
    }
    const standalone = marker === 0x00 || marker === 0x01 || marker === SOI;
    if (standalone || (marker >= 0xd0 && marker <= 0xd7)) {
      throw new JpegRejectedError('malformed', 'Marqueur hors de sa place.');
    }

    if (position + 2 > input.length) {
      throw new JpegRejectedError('malformed', 'Segment tronqué.');
    }
    const length = input.readUInt16BE(position);
    const end = position + length;
    if (length < 2 || end > input.length) {
      throw new JpegRejectedError('malformed', 'Longueur de segment incohérente.');
    }
    const payload = input.subarray(position + 2, end);

    if (marker === SOS) {
      if (!sawFrame) {
        throw new JpegRejectedError('malformed', 'Balayage avant toute trame.');
      }
      const scanEnd = endOfEntropyData(input, end);
      kept.push(segment(marker, payload), input.subarray(end, scanEnd));
      sawScan = true;
      position = scanEnd;
      continue;
    }
    if (marker >= APP0 && marker <= 0xef) {
      const application = applicationSegment(marker, payload);
      if (application !== null) {
        kept.push(application);
      }
    } else if (isStructural(marker)) {
      sawFrame ||= isStartOfFrame(marker);
      kept.push(segment(marker, payload));
    } else if (marker !== COM) {
      throw new JpegRejectedError(
        'unsupported',
        `Marqueur JPEG non pris en charge : 0x${marker.toString(16)}.`,
      );
    }
    position = end;
  }
}
