import { fnv1a32, rotationOffset } from './hash';

/**
 * Le hachage est GELÉ : il décide des décalages de rotation, donc de chaque
 * programme déjà généré. Toute réécriture (celle qui a sorti `Math.imul` de
 * la boucle, par exemple, pour la vitesse sous Jest) doit rendre les mêmes
 * valeurs au bit près. Les trois premières sont les vecteurs de référence
 * publiés de FNV-1a 32 bits ; la dernière a la forme d'une vraie graine.
 */
describe('fnv1a32', () => {
  it.each([
    ['', 0x811c9dc5],
    ['a', 0xe40c292c],
    ['foobar', 0xbf9cf968],
    ['programme|STRENGTH|BEGINNER|3|45|banc,barre', 0x49cd1236],
  ])('%j rend la valeur de référence', (text, attendu) => {
    expect(fnv1a32(text)).toBe(attendu);
  });

  it('rend toujours un entier non signé sur 32 bits', () => {
    for (const text of ['x', 'Développé couché', '0123456789'.repeat(20)]) {
      const hash = fnv1a32(text);
      expect(Number.isInteger(hash)).toBe(true);
      expect(hash).toBeGreaterThanOrEqual(0);
      expect(hash).toBeLessThanOrEqual(0xffffffff);
    }
  });
});

describe('rotationOffset', () => {
  it('reste dans le pool, et vaut 0 pour un pool vide', () => {
    expect(rotationOffset('graine', 2, 3, 0)).toBe(0);
    for (let week = 1; week <= 12; week += 1) {
      const offset = rotationOffset('graine', 1, week, 7);
      expect(offset).toBeGreaterThanOrEqual(0);
      expect(offset).toBeLessThan(7);
    }
  });
});
