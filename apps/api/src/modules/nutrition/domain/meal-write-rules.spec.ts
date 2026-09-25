import {
  compositionChange,
  computedFieldsChanged,
  computedFieldsSent,
  creationPlan,
  patchConflict,
} from './meal-write-rules';

const ITEMS = [{ id: '5f0c3c1e-0000-4000-8000-000000000001', foodCode: 990001, quantityG: 120 }];

describe('compositionChange', () => {
  it('absent : on garde ; vide : on retire ; non vide : on remplace', () => {
    expect(compositionChange(undefined)).toEqual({ kind: 'keep' });
    expect(compositionChange([])).toEqual({ kind: 'clear' });
    expect(compositionChange(ITEMS)).toEqual({ kind: 'replace', items: ITEMS });
  });
});

describe('computedFieldsSent', () => {
  it('compte un champ ENVOYÉ à null : c’est encore prétendre le dire', () => {
    expect(computedFieldsSent({ kcal: 500, proteinG: null, carbsG: undefined })).toEqual([
      'kcal',
      'proteinG',
    ]);
    expect(computedFieldsSent({})).toEqual([]);
  });
});

describe('computedFieldsChanged', () => {
  const stored = {
    kcal: 390,
    proteinG: 40,
    carbsG: 44,
    fatG: null,
    quantity: 320,
    quantityUnit: 'GRAM',
  } as const;

  it('renvoyer à l’identique ce qu’on a lu n’est pas une correction', () => {
    // Ce que l'écran de correction déjà publié envoie : TOUTES les clés.
    expect(computedFieldsChanged({ ...stored }, stored)).toEqual([]);
  });

  it('nomme ce qui change, null compris, et ignore ce qui n’est pas envoyé', () => {
    expect(computedFieldsChanged({ ...stored, kcal: 391, fatG: 3, carbsG: null }, stored)).toEqual([
      'kcal',
      'carbsG',
      'fatG',
    ]);
    expect(computedFieldsChanged({ quantity: 300 }, stored)).toEqual(['quantity']);
    expect(computedFieldsChanged({}, stored)).toEqual([]);
  });
});

describe('creationPlan', () => {
  it('saisi à la main : les calories sont obligatoires', () => {
    expect(creationPlan({ kcal: 500 })).toEqual({ kind: 'manual', kcal: 500 });
    expect(creationPlan({ kcal: 500, components: [] })).toEqual({ kind: 'manual', kcal: 500 });
    expect(creationPlan({})).toEqual({
      kind: 'refused',
      message: expect.stringContaining('calories') as unknown,
    });
  });

  it('composé : aucun champ calculé ne doit accompagner les aliments', () => {
    expect(creationPlan({ components: ITEMS })).toEqual({ kind: 'composed', items: ITEMS });
    const refused = creationPlan({ components: ITEMS, kcal: 500, quantityUnit: null });
    expect(refused.kind).toBe('refused');
    // Le message NOMME ce qui gêne : le client sait quoi retirer.
    expect(refused.kind === 'refused' && refused.message).toMatch(/kcal, quantityUnit/);
  });
});

describe('patchConflict', () => {
  it('une nouvelle composition ne se mêle à aucun total envoyé', () => {
    expect(patchConflict(compositionChange(ITEMS), ['fatG'], false)).toMatch(/fatG/);
    expect(patchConflict(compositionChange(ITEMS), [], true)).toBeNull();
  });

  it('les totaux d’un repas COMPOSÉ ne se corrigent pas à la main sans retirer la composition', () => {
    const message = patchConflict(compositionChange(undefined), ['kcal'], true);
    expect(message).toMatch(/retire d’abord sa composition/);
    // Un repas saisi à la main se corrige comme avant.
    expect(patchConflict(compositionChange(undefined), ['kcal'], false)).toBeNull();
    // Le nom, le moment ou l'heure d'un repas composé restent libres.
    expect(patchConflict(compositionChange(undefined), [], true)).toBeNull();
  });

  it('retirer la composition rend la main : le même corps peut corriger les totaux', () => {
    expect(patchConflict(compositionChange([]), ['kcal', 'proteinG'], true)).toBeNull();
  });
});
