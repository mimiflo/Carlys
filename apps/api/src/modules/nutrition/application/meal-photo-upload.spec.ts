import { MEAL_PHOTO_MAX_BYTES } from '@carlys/api-contracts';
import {
  BadRequestException,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { acceptMealPhoto } from './meal-photo-upload';

const PHOTO = readFileSync(
  join(__dirname, '..', '..', '..', '..', 'test', 'fixtures', 'jpeg', 'repas-exif-gps.jpg'),
);
const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);

describe('acceptMealPhoto', () => {
  it('un JPEG déclaré image/jpeg : accepté, et rendu SANS ses métadonnées', () => {
    const stored = acceptMealPhoto({ mimeType: 'image/jpeg', content: PHOTO });

    expect(stored.includes(Buffer.from('Exif'))).toBe(false);
    expect(stored.length).toBeLessThan(PHOTO.length);
  });

  it('des octets PNG annoncés image/jpeg : 415, la signature fait foi', () => {
    expect(() => acceptMealPhoto({ mimeType: 'image/jpeg', content: PNG_1X1 })).toThrow(
      UnsupportedMediaTypeException,
    );
  });

  it('un vrai JPEG déclaré sous un autre type : 415 aussi', () => {
    expect(() => acceptMealPhoto({ mimeType: 'image/png', content: PHOTO })).toThrow(
      /Seul le JPEG est accepté/,
    );
  });

  it('un JPEG tronqué : 415, jamais stocké à moitié', () => {
    expect(() =>
      acceptMealPhoto({ mimeType: 'image/jpeg', content: PHOTO.subarray(0, 900) }),
    ).toThrow(/illisible ou tronqué/);
  });

  it('vide : 400 ; au-delà de 5 Mo : 413', () => {
    expect(() => acceptMealPhoto({ mimeType: 'image/jpeg', content: Buffer.alloc(0) })).toThrow(
      BadRequestException,
    );
    const huge = Buffer.concat([PHOTO, Buffer.alloc(MEAL_PHOTO_MAX_BYTES)]);
    expect(() => acceptMealPhoto({ mimeType: 'image/jpeg', content: huge })).toThrow(
      PayloadTooLargeException,
    );
  });
});
