import { createHash } from 'node:crypto';
import { mediaIdFor } from './seed-media';

const checksum = (content: string): string => createHash('sha256').update(content).digest('hex');

describe('versions des photos du seed', () => {
  it('garde la même URL quand le seed est rejoué sans changer la photo', () => {
    const first = mediaIdFor('developpe-couche', checksum('photo'));
    expect(mediaIdFor('developpe-couche', checksum('photo'))).toBe(first);
    expect(first).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  });

  it('change l’URL après remplacement pour éviter l’ancien cache immutable', () => {
    expect(mediaIdFor('developpe-couche', checksum('nouvelle photo'))).not.toBe(
      mediaIdFor('developpe-couche', checksum('ancienne photo')),
    );
  });

  it('ne partage pas un identifiant entre deux exercices', () => {
    expect(mediaIdFor('pompes', checksum('photo'))).not.toBe(
      mediaIdFor('developpe-couche', checksum('photo')),
    );
  });
});
