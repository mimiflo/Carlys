import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { readImageSize } from '../../modules/media/application/image-size';
import {
  hasJpegSignature,
  type JpegRejection,
  JpegRejectedError,
  stripJpegMetadata,
} from './jpeg-metadata';

/**
 * Une VRAIE photo : JPEG écrit par Pillow, avec un EXIF portant une position
 * GPS (48° 51′ 29,52″ N, 2° 17′ 40,2″ E), une marque et un modèle
 * d'appareil, un XMP qui répète la position, un bloc IPTC (ville), un
 * commentaire (une adresse) et un profil ICC. Voir le README du dossier.
 */
const FIXTURE = readFileSync(
  join(__dirname, '..', '..', '..', 'test', 'fixtures', 'jpeg', 'repas-exif-gps.jpg'),
);

interface Segment {
  readonly marker: number;
  readonly offset: number;
  readonly payload: Buffer;
}

/** Les segments d'en-tête, jusqu'au premier balayage (SOS) compris. */
function headerSegments(jpeg: Buffer): Segment[] {
  const segments: Segment[] = [];
  let offset = 2;
  while (offset + 4 <= jpeg.length) {
    const marker = jpeg[offset + 1]!;
    const length = jpeg.readUInt16BE(offset + 2);
    segments.push({ marker, offset, payload: jpeg.subarray(offset + 4, offset + 2 + length) });
    if (marker === 0xda) {
      break;
    }
    offset += 2 + length;
  }
  return segments;
}

function markersOf(jpeg: Buffer): number[] {
  return headerSegments(jpeg).map((segment) => segment.marker);
}

function segment(marker: number, payload: Buffer | string): Buffer {
  const body = typeof payload === 'string' ? Buffer.from(payload, 'latin1') : payload;
  const header = Buffer.from([0xff, marker, 0, 0]);
  header.writeUInt16BE(body.length + 2, 2);
  return Buffer.concat([header, body]);
}

/** Insère des segments juste après SOI. */
function afterSoi(jpeg: Buffer, ...segments: Buffer[]): Buffer {
  return Buffer.concat([jpeg.subarray(0, 2), ...segments, jpeg.subarray(2)]);
}

/** Insère des segments juste avant le premier balayage. */
function beforeScan(jpeg: Buffer, ...segments: Buffer[]): Buffer {
  const sos = headerSegments(jpeg).find((s) => s.marker === 0xda)!;
  return Buffer.concat([jpeg.subarray(0, sos.offset), ...segments, jpeg.subarray(sos.offset)]);
}

/** Retire l'APP0 d'origine, pour en poser un autre à sa place. */
function dropApp0(jpeg: Buffer): Buffer {
  const app0 = headerSegments(jpeg).find((s) => s.marker === 0xe0);
  if (app0 === undefined) {
    return jpeg;
  }
  const end = app0.offset + 4 + app0.payload.length;
  return Buffer.concat([jpeg.subarray(0, app0.offset), jpeg.subarray(end)]);
}

/** Ce qui décode l'image : de la première table de quantification à la fin. */
function imageData(jpeg: Buffer): Buffer {
  const dqt = headerSegments(jpeg).find((s) => s.marker === 0xdb)!;
  return jpeg.subarray(dqt.offset);
}

function rejectionOf(bytes: Buffer): JpegRejection | undefined {
  try {
    stripJpegMetadata(bytes);
    return undefined;
  } catch (error) {
    return error instanceof JpegRejectedError ? error.reason : undefined;
  }
}

const has = (bytes: Buffer, text: string): boolean => bytes.includes(Buffer.from(text, 'latin1'));

describe('stripJpegMetadata — sur une vraie photo porteuse d’un EXIF GPS', () => {
  const stripped = stripJpegMetadata(FIXTURE);

  it('la photo d’essai porte bien ce qu’on prétend retirer (garde du garde)', () => {
    expect(hasJpegSignature(FIXTURE)).toBe(true);
    expect(has(FIXTURE, 'Exif\0\0')).toBe(true);
    // Le pointeur vers le répertoire GPS (étiquette 0x8825), en gros-boutiste.
    expect(FIXTURE.includes(Buffer.from([0x88, 0x25]))).toBe(true);
    expect(has(FIXTURE, 'exif:GPSLatitude')).toBe(true);
    expect(has(FIXTURE, 'iPhone 15 Pro')).toBe(true);
    expect(has(FIXTURE, 'Photoshop 3.0')).toBe(true);
    expect(has(FIXTURE, 'Paris')).toBe(true);
    expect(has(FIXTURE, '12 rue des Lilas')).toBe(true);
    expect(markersOf(FIXTURE)).toEqual(
      expect.arrayContaining([0xe0, 0xe1, 0xe2, 0xed, 0xfe, 0xdb, 0xc0, 0xc4, 0xda]),
    );
  });

  it('aucune trace de la position, de l’appareil, de l’adresse ni de la ville ne sort', () => {
    for (const trace of [
      'Exif',
      'GPS',
      'exif:',
      'http://ns.adobe.com',
      'iPhone',
      'Apple',
      'Photoshop',
      '8BIM',
      'Paris',
      'Lilas',
      '2026:09:25',
    ]) {
      expect({ trace, present: has(stripped, trace) }).toEqual({ trace, present: false });
    }
    // Plus AUCUN segment APP1 (EXIF, XMP), APP13 (IPTC) ni COM.
    const markers = markersOf(stripped);
    expect(markers).not.toContain(0xe1);
    expect(markers).not.toContain(0xed);
    expect(markers).not.toContain(0xfe);
  });

  it('garde JFIF et le profil ICC, et l’image elle-même octet pour octet', () => {
    expect(markersOf(stripped)).toEqual([
      0xe0, 0xe2, 0xdb, 0xdb, 0xc0, 0xc4, 0xc4, 0xc4, 0xc4, 0xda,
    ]);
    expect(has(stripped, 'JFIF\0')).toBe(true);
    expect(has(stripped, 'ICC_PROFILE\0')).toBe(true);
    // Tables, trame, balayage et fin d'image : identiques. Rien n'a été
    // décodé ni réencodé, donc aucune perte.
    expect(imageData(stripped).equals(imageData(FIXTURE))).toBe(true);
    expect(readImageSize(stripped)).toEqual({ width: 48, height: 32 });
    expect(stripped.length).toBeLessThan(FIXTURE.length);
  });

  it('est idempotent : filtrer deux fois ne change plus rien', () => {
    expect(stripJpegMetadata(stripped).equals(stripped)).toBe(true);
  });
});

describe('stripJpegMetadata — où que la métadonnée se cache', () => {
  it('un EXIF rangé ENTRE les tables, après la trame, part aussi', () => {
    const exif = segment(0xe1, 'Exif\0\0GPS-cache');
    const hidden = beforeScan(FIXTURE, exif);
    expect(has(hidden, 'GPS-cache')).toBe(true);

    expect(has(stripJpegMetadata(hidden), 'GPS-cache')).toBe(false);
  });

  it('tout ce qui suit la fin d’image part : un second JPEG et son EXIF', () => {
    // Certains appareils rangent après EOI une seconde image (MPF), avec son
    // propre EXIF.
    const trailing = Buffer.concat([FIXTURE, FIXTURE]);

    const out = stripJpegMetadata(trailing);

    expect(out.subarray(-2)).toEqual(Buffer.from([0xff, 0xd9]));
    expect(has(out, 'Exif')).toBe(false);
    expect(out.equals(stripJpegMetadata(FIXTURE))).toBe(true);
  });

  it('la vignette JFIF est retirée : une vignette est une seconde image', () => {
    const jfif = Buffer.concat([
      Buffer.from('JFIF\0', 'latin1'),
      Buffer.from([1, 1, 0, 0, 1, 0, 1, 2, 1]), // version, unité, densités, vignette 2 × 1
      Buffer.from([10, 20, 30, 40, 50, 60]), // ses six octets RVB
    ]);
    const withThumbnail = afterSoi(dropApp0(FIXTURE), segment(0xe0, jfif));

    const app0 = headerSegments(stripJpegMetadata(withThumbnail)).find((s) => s.marker === 0xe0)!;

    expect(app0.payload.length).toBe(14);
    expect([app0.payload[12], app0.payload[13]]).toEqual([0, 0]);
  });

  it('APP2 : le profil ICC reste, MPF et FlashPix partent', () => {
    const out = stripJpegMetadata(
      afterSoi(FIXTURE, segment(0xe2, 'MPF\0II*\0images-cachees'), segment(0xe2, 'FPXR\0x')),
    );

    expect(has(out, 'images-cachees')).toBe(false);
    expect(has(out, 'FPXR')).toBe(false);
    expect(has(out, 'ICC_PROFILE\0')).toBe(true);
  });

  it('APP14 « Adobe » reste à sa taille exacte (paramètre de décodage), pas au-delà', () => {
    const adobe = segment(0xee, Buffer.from('Adobe\0\x64\0\0\0\0\x01', 'latin1'));
    const padded = segment(0xee, 'Adobe-et-bien-plus-que-douze-octets');

    const out = stripJpegMetadata(afterSoi(FIXTURE, adobe, padded));

    expect(markersOf(out).filter((marker) => marker === 0xee)).toHaveLength(1);
    expect(has(out, 'bien-plus')).toBe(false);
  });

  it('les autres APPn (APP3 à APP15) partent, quel que soit leur contenu', () => {
    const others = [0xe3, 0xe5, 0xe9, 0xeb, 0xef].map((marker) =>
      segment(marker, `donnee-app-${marker.toString(16)}`),
    );

    const out = stripJpegMetadata(afterSoi(FIXTURE, ...others));

    expect(has(out, 'donnee-app')).toBe(false);
  });
});

describe('stripJpegMetadata — ce qui n’est pas un JPEG lisible est refusé', () => {
  const PNG_1X1 = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    'base64',
  );

  it('des octets PNG, même annoncés image/jpeg : pas un JPEG', () => {
    expect(hasJpegSignature(PNG_1X1)).toBe(false);
    expect(rejectionOf(PNG_1X1)).toBe('not-jpeg');
  });

  it('vide, texte, ou signature seule : pas un JPEG, ou illisible', () => {
    expect(rejectionOf(Buffer.alloc(0))).toBe('not-jpeg');
    expect(rejectionOf(Buffer.from('<?php echo 1; ?>'))).toBe('not-jpeg');
    expect(rejectionOf(Buffer.from([0xff, 0xd8, 0xff]))).toBe('malformed');
  });

  it('tronqué au milieu de l’image : illisible', () => {
    expect(rejectionOf(FIXTURE.subarray(0, FIXTURE.length - 40))).toBe('malformed');
    const sos = headerSegments(FIXTURE).find((s) => s.marker === 0xda)!;
    expect(rejectionOf(FIXTURE.subarray(0, sos.offset))).toBe('malformed');
  });

  it('une longueur de segment qui déborde du fichier : illisible', () => {
    const lying = Buffer.concat([
      Buffer.from([0xff, 0xd8, 0xff, 0xe1, 0xff, 0xff]),
      Buffer.alloc(8),
    ]);
    expect(rejectionOf(lying)).toBe('malformed');
  });

  it('un balayage sans trame : illisible', () => {
    const scanFirst = Buffer.concat([
      Buffer.from([0xff, 0xd8]),
      segment(0xda, Buffer.from([1, 1, 0, 0, 63, 0])),
      Buffer.from([0x12, 0x34, 0xff, 0xd9]),
    ]);
    expect(rejectionOf(scanFirst)).toBe('malformed');
  });

  it('un marqueur réservé (extension JPEG-LS, 0xF7) : non pris en charge, jamais recopié', () => {
    expect(rejectionOf(afterSoi(FIXTURE, segment(0xf7, 'extension')))).toBe('unsupported');
  });
});
