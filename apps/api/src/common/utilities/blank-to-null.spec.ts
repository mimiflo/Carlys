import { blankToNull } from './blank-to-null';

describe('blankToNull', () => {
  it('absent, null, vide ou blanc : pas de texte', () => {
    expect(blankToNull(undefined)).toBeNull();
    expect(blankToNull(null)).toBeNull();
    expect(blankToNull('')).toBeNull();
    expect(blankToNull(' \n\t ')).toBeNull();
  });

  it('un texte réel est rendu sans les blancs autour, et seulement autour', () => {
    expect(blankToNull('  On y va ?  ')).toBe('On y va ?');
    expect(blankToNull('Deux  espaces')).toBe('Deux  espaces');
  });
});
