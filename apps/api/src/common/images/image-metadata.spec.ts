import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { crc32 } from 'node:zlib';
import { readImageSize } from '../../modules/media/application/image-size';
import { ImageRejectedError, stripImageMetadata } from './image-metadata';

/** PNG 1×1 réel (IHDR, IDAT, IEND), celui de la suite e2e des médias. */
const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);
const GPS = 'GPSLatitude 48/1 51/1 2952/100';

function pngChunk(type: string, data: Buffer | string): Buffer {
  const body = Buffer.concat([Buffer.from(type, 'latin1'), Buffer.from(data)]);
  const length = Buffer.alloc(4);
  length.writeUInt32BE(body.length - 4);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([length, body, crc]);
}

/** Insère des chunks juste après IHDR (8 + 25 octets). */
function afterIhdr(...chunks: Buffer[]): Buffer {
  return Buffer.concat([PNG_1X1.subarray(0, 33), ...chunks, PNG_1X1.subarray(33)]);
}

function riffChunk(fourcc: string, data: Buffer | string): Buffer {
  const body = Buffer.from(data);
  const header = Buffer.alloc(8);
  header.write(fourcc, 0, 'latin1');
  header.writeUInt32LE(body.length, 4);
  return Buffer.concat([header, body, body.length % 2 === 1 ? Buffer.alloc(1) : Buffer.alloc(0)]);
}

function webp(...chunks: Buffer[]): Buffer {
  const body = Buffer.concat([Buffer.from('WEBP', 'latin1'), ...chunks]);
  const header = Buffer.alloc(8);
  header.write('RIFF', 0, 'latin1');
  header.writeUInt32LE(body.length, 4);
  return Buffer.concat([header, body]);
}

/** VP8X 2×3 avec les drapeaux ICC, EXIF et XMP levés. */
function vp8x(flags = 0x20 | 0x08 | 0x04): Buffer {
  const data = Buffer.alloc(10);
  data[0] = flags;
  data.writeUIntLE(1, 4, 3);
  data.writeUIntLE(2, 7, 3);
  return riffChunk('VP8X', data);
}
const VP8L = riffChunk('VP8L', Buffer.from([0x2f, 0x01, 0x80, 0x00, 0x00, 0x07, 0x10, 0x11]));

describe('stripImageMetadata — PNG', () => {
  it('retire eXIf, tEXt, zTXt, iTXt (XMP) et tIME ; garde l’image et le profil', () => {
    const iccp = pngChunk('iCCP', 'sRGB\0\0profil');
    const dirty = afterIhdr(
      iccp,
      pngChunk('eXIf', `MM\0*${GPS}`),
      pngChunk('tEXt', 'Comment\0Chez moi, 12 rue des Lilas'),
      pngChunk('zTXt', 'Author\0\0x'),
      pngChunk('iTXt', `XML:com.adobe.xmp\0\0\0\0\0<x:xmpmeta>${GPS}</x:xmpmeta>`),
      pngChunk('tIME', Buffer.alloc(7)),
    );

    const clean = stripImageMetadata('image/png', dirty);

    expect(clean).toEqual(afterIhdr(iccp));
    expect(clean.toString('latin1')).not.toMatch(/GPS|Lilas|xmp|eXIf|tIME/);
    expect(readImageSize(clean)).toEqual({ width: 1, height: 1 });
  });

  it('un PNG propre ressort octet pour octet, et ce qui suit IEND part', () => {
    expect(stripImageMetadata('image/png', PNG_1X1)).toEqual(PNG_1X1);
    const trailing = Buffer.concat([PNG_1X1, Buffer.from(`second fichier ${GPS}`)]);
    expect(stripImageMetadata('image/png', trailing)).toEqual(PNG_1X1);
  });

  it('refuse ce qu’il ne sait pas lire : signature, tronqué, chunk critique inconnu', () => {
    expect(() => stripImageMetadata('image/png', Buffer.from('pas une image'))).toThrow(
      ImageRejectedError,
    );
    expect(() => stripImageMetadata('image/png', PNG_1X1.subarray(0, 40))).toThrow(
      ImageRejectedError,
    );
    expect(() => stripImageMetadata('image/png', afterIhdr(pngChunk('ZZZZ', 'x')))).toThrow(
      ImageRejectedError,
    );
  });

  it('refuse un PNG sans image : IHDR puis IEND, aucun IDAT', () => {
    const empty = Buffer.concat([PNG_1X1.subarray(0, 33), pngChunk('IEND', '')]);
    expect(() => stripImageMetadata('image/png', empty)).toThrow(ImageRejectedError);
  });
});

describe('stripImageMetadata — WebP', () => {
  it('retire EXIF et XMP, baisse leurs drapeaux VP8X et recalcule la taille RIFF', () => {
    const iccp = riffChunk('ICCP', 'profil');
    const dirty = webp(
      vp8x(),
      iccp,
      VP8L,
      riffChunk('EXIF', `MM\0*${GPS}`),
      riffChunk('XMP ', `<x:xmpmeta>${GPS}</x:xmpmeta>`),
    );

    const clean = stripImageMetadata('image/webp', dirty);

    expect(clean).toEqual(webp(vp8x(0x20), iccp, VP8L));
    expect(clean.readUInt32LE(4)).toBe(clean.length - 8);
    expect(clean.toString('latin1')).not.toMatch(/GPS|EXIF|XMP/);
    expect(readImageSize(clean)).toEqual({ width: 2, height: 3 });
  });

  it('un WebP simple ressort tel quel ; un RIFF qui ment sur sa taille est refusé', () => {
    const simple = webp(VP8L);
    expect(stripImageMetadata('image/webp', simple)).toEqual(simple);

    const lying = Buffer.from(simple);
    lying.writeUInt32LE(simple.length * 2, 4);
    expect(() => stripImageMetadata('image/webp', lying)).toThrow(ImageRejectedError);
    expect(() => stripImageMetadata('image/webp', PNG_1X1)).toThrow(ImageRejectedError);
  });

  it('refuse un WebP sans image : vide, ou réduit à son EXIF', () => {
    expect(() => stripImageMetadata('image/webp', webp())).toThrow(ImageRejectedError);
    expect(() => stripImageMetadata('image/webp', webp(riffChunk('EXIF', `MM\0*${GPS}`)))).toThrow(
      ImageRejectedError,
    );
    expect(() => stripImageMetadata('image/webp', webp(vp8x(), riffChunk('XMP ', GPS)))).toThrow(
      ImageRejectedError,
    );
  });

  it('refuse un VP8X qui n’est pas le premier chunk, ou trop court', () => {
    expect(() => stripImageMetadata('image/webp', webp(VP8L, vp8x(0)))).toThrow(ImageRejectedError);
    expect(() =>
      stripImageMetadata('image/webp', webp(riffChunk('VP8X', Buffer.alloc(4)), VP8L)),
    ).toThrow(ImageRejectedError);
  });
});

describe('stripImageMetadata — JPEG et le reste', () => {
  it('JPEG : le filtre des photos de repas, EXIF GPS compris', () => {
    const photo = readFileSync(
      join(__dirname, '..', '..', '..', 'test', 'fixtures', 'jpeg', 'repas-exif-gps.jpg'),
    );
    expect(photo.includes(Buffer.from('Exif\0', 'latin1'))).toBe(true);

    const clean = stripImageMetadata('image/jpeg', photo);

    expect(clean.includes(Buffer.from('Exif\0', 'latin1'))).toBe(false);
    expect(clean.toString('latin1')).not.toMatch(/iPhone|Lilas|GPSLatitude/);
  });

  it('un JPEG illisible et un type qu’il ne sait pas nettoyer sont refusés', () => {
    expect(() => stripImageMetadata('image/jpeg', PNG_1X1)).toThrow(ImageRejectedError);
    expect(() => stripImageMetadata('image/avif', PNG_1X1)).toThrow(ImageRejectedError);
  });
});
