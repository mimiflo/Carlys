/**
 * Dimensions d'une image, lues dans son en-tête.
 *
 * Écrit à la main plutôt qu'ajouté en dépendance : on a besoin de deux entiers
 * pour quatre formats, pas d'un décodeur. Une image dont l'en-tête n'est pas
 * reconnu rend `null` — l'absence de dimensions n'empêche jamais un dépôt.
 */
export function readImageSize(buffer: Buffer): { width: number; height: number } | null {
  return png(buffer) ?? jpeg(buffer) ?? webp(buffer);
}

function png(b: Buffer): { width: number; height: number } | null {
  // Signature PNG, puis le chunk IHDR : largeur et hauteur en gros-boutiste.
  if (b.length < 24 || b.readUInt32BE(0) !== 0x89504e47) return null;
  return { width: b.readUInt32BE(16), height: b.readUInt32BE(20) };
}

function jpeg(b: Buffer): { width: number; height: number } | null {
  if (b.length < 4 || b.readUInt16BE(0) !== 0xffd8) return null;
  let offset = 2;
  while (offset + 9 < b.length) {
    if (b[offset] !== 0xff) return null;
    const marker = b[offset + 1]!;
    const length = b.readUInt16BE(offset + 2);
    // SOF0…SOF15, hors marqueurs qui ne décrivent pas une trame.
    const isStartOfFrame = marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker);
    if (isStartOfFrame) {
      return { height: b.readUInt16BE(offset + 5), width: b.readUInt16BE(offset + 7) };
    }
    offset += 2 + length;
  }
  return null;
}

function webp(b: Buffer): { width: number; height: number } | null {
  if (b.length < 30 || b.toString('ascii', 0, 4) !== 'RIFF') return null;
  if (b.toString('ascii', 8, 12) !== 'WEBP') return null;

  const format = b.toString('ascii', 12, 16);
  if (format === 'VP8X') {
    // Trois octets par dimension, petit-boutiste, stockés diminués de un.
    return {
      width: 1 + (b[24]! | (b[25]! << 8) | (b[26]! << 16)),
      height: 1 + (b[27]! | (b[28]! << 8) | (b[29]! << 16)),
    };
  }
  if (format === 'VP8L') {
    const bits = b.readUInt32LE(21);
    return {
      width: 1 + (bits & 0x3fff),
      height: 1 + ((bits >> 14) & 0x3fff),
    };
  }
  if (format === 'VP8 ') {
    return {
      width: b.readUInt16LE(26) & 0x3fff,
      height: b.readUInt16LE(28) & 0x3fff,
    };
  }
  return null;
}
