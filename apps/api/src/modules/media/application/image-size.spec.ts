import { readImageSize } from './image-size';

/**
 * Lecture des dimensions dans l'en-tête d'une image.
 *
 * Écrit à la main plutôt qu'ajouté en dépendance : il fallait deux entiers,
 * pas un décodeur. Ces tests sont la contrepartie de ce choix — un en-tête mal
 * lu donnerait des dimensions fausses, stockées puis servies telles quelles.
 */
describe('readImageSize', () => {
  it('lit un PNG', () => {
    const png = Buffer.alloc(24);
    png.writeUInt32BE(0x89504e47, 0);
    png.writeUInt32BE(1920, 16);
    png.writeUInt32BE(1080, 20);

    expect(readImageSize(png)).toEqual({ width: 1920, height: 1080 });
  });

  it('lit un JPEG en traversant les segments jusqu’au SOF', () => {
    // APP0 de 16 octets, puis SOF0 qui porte les dimensions.
    const jpeg = Buffer.concat([
      Buffer.from([0xff, 0xd8]),
      Buffer.from([0xff, 0xe0, 0x00, 0x10]),
      Buffer.alloc(14),
      Buffer.from([0xff, 0xc0, 0x00, 0x11, 0x08]),
      Buffer.from([0x02, 0x58, 0x03, 0x20]), // 600 de haut, 800 de large
      Buffer.alloc(8),
    ]);

    expect(readImageSize(jpeg)).toEqual({ width: 800, height: 600 });
  });

  it('lit un WebP sans perte (VP8L)', () => {
    const webp = Buffer.alloc(30);
    webp.write('RIFF', 0, 'ascii');
    webp.write('WEBP', 8, 'ascii');
    webp.write('VP8L', 12, 'ascii');
    // Largeur et hauteur sur 14 bits chacune, stockées diminuées de un.
    webp.writeUInt32LE((319 & 0x3fff) | ((239 & 0x3fff) << 14), 21);

    expect(readImageSize(webp)).toEqual({ width: 320, height: 240 });
  });

  it('rend null sur un en-tête inconnu — l’absence de dimensions n’empêche rien', () => {
    expect(readImageSize(Buffer.from('pas une image'))).toBeNull();
    expect(readImageSize(Buffer.alloc(0))).toBeNull();
  });
});
