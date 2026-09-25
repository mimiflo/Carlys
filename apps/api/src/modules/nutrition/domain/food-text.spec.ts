import { normalizeFoodText, searchWords, shortFoodName } from './food-text';

describe('normalizeFoodText', () => {
  it('minuscules, sans accents, ponctuation en espaces', () => {
    expect(normalizeFoodText('Poulet, filet, sans peau, cuit')).toBe('poulet filet sans peau cuit');
    expect(normalizeFoodText('Pâté de foie (porc)')).toBe('pate de foie porc');
    expect(normalizeFoodText('Bœuf, haché 5% MG, cuit')).toBe('boeuf hache 5 mg cuit');
  });

  it('sépare les ligatures que la décomposition Unicode laisse entières', () => {
    // « œ » et « æ » sont des lettres pour Unicode : sans table dédiée, « bœuf »
    // deviendrait « b uf » et ne se retrouverait par aucune saisie.
    expect(normalizeFoodText('Œuf, dur')).toBe('oeuf dur');
    expect(normalizeFoodText('Cæsar')).toBe('caesar');
    // Ligature typographique : NFKD s'en charge.
    expect(normalizeFoodText('Soufﬂé')).toBe('souffle');
  });

  it('ne laisse survivre aucun joker SQL', () => {
    expect(normalizeFoodText("100%_riz\\l'été")).toBe('100 riz l ete');
    expect(normalizeFoodText('  ,,  ')).toBe('');
  });
});

describe('shortFoodName', () => {
  it('garde le segment avant la première virgule', () => {
    expect(shortFoodName('Poulet, filet, sans peau, cuit')).toBe('Poulet');
    expect(shortFoodName('Riz blanc, cuit')).toBe('Riz blanc');
  });

  it('un nom sans virgule est son propre nom court', () => {
    expect(shortFoodName('Pastis')).toBe('Pastis');
    expect(shortFoodName(', étrange')).toBe(', étrange');
  });
});

describe('searchWords', () => {
  it('normalise la saisie comme la clé stockée, dans l’ordre, sans doublon', () => {
    expect(searchWords('  Œuf DUR œuf ')).toEqual(['oeuf', 'dur']);
    expect(searchWords('!!')).toEqual([]);
  });
});
