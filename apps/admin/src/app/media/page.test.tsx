import { describe, expect, it } from 'vitest';
import { formatBytes } from './page';

/**
 * Le poids d'un média se lit d'un coup d'œil ou ne sert à rien : personne ne
 * compare « 3 145 728 » à « 524 288 » sans compter les chiffres.
 */
describe('formatBytes', () => {
  it('garde les octets tant qu’ils se lisent', () => {
    expect(formatBytes(512)).toBe('512 o');
  });

  it('passe aux kilo-octets sans décimale : elle n’apprend rien', () => {
    expect(formatBytes(2048)).toBe('2 Ko');
    expect(formatBytes(1024 * 900)).toBe('900 Ko');
  });

  it('passe aux méga-octets avec UNE décimale, virgule française', () => {
    expect(formatBytes(1024 * 1024 * 3.5)).toBe('3,5 Mo');
  });
});
