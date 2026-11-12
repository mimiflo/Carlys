import { storedBodyMetricId, uuidv5 } from './body-metric-id';

describe('storedBodyMetricId', () => {
  const userA = '11111111-2222-4333-8444-555555555555';
  const userB = '99999999-2222-4333-8444-555555555555';
  const imported = '5d29b8e9-c611-5505-8f1d-9d5517250899';

  it('calcule un UUID v5 conforme (vecteur de la RFC, rejoué par Python)', () => {
    expect(uuidv5('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'python.org')).toBe(
      '886313e1-3b8a-5372-9b90-0c9aee199e5d',
    );
  });

  it('range un identifiant v5 dans l’espace du compte, en v5', () => {
    expect(storedBodyMetricId(userA, imported)).toBe('4d898744-3240-54ab-b5ac-7254bfbddc03');
    expect(storedBodyMetricId(userA, imported)).toBe(storedBodyMetricId(userA, imported));
    expect(storedBodyMetricId(userB, imported)).not.toBe(storedBodyMetricId(userA, imported));
  });

  it('garde tel quel un identifiant v4 (saisie à la main)', () => {
    const manual = '0f8fad5b-d9cb-469f-a165-70867728950e';
    expect(storedBodyMetricId(userA, manual)).toBe(manual);
  });
});
