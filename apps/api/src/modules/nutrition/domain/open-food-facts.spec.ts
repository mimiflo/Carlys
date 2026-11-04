import { toPackagedFood } from './open-food-facts';

describe('toPackagedFood', () => {
  const code = '3017620422003';

  it('lit le nom français, la marque, les valeurs pour 100 g et la portion', () => {
    expect(
      toPackagedFood(code, {
        product_name_fr: '  Pâte   à tartiner ',
        product_name: 'Hazelnut spread',
        brands: 'Nutella, Ferrero',
        serving_quantity: 15,
        product_quantity_unit: 'g',
        nutriments: {
          'energy-kcal_100g': 539,
          proteins_100g: 6.3,
          carbohydrates_100g: '57.5',
          fat_100g: 30.9,
        },
      }),
    ).toEqual({
      barcode: code,
      name: 'Pâte à tartiner',
      brand: 'Nutella',
      per100g: { kcal: 539, proteinG: 6.3, carbsG: 57.5, fatG: 30.9 },
      liquid: false,
      servingQuantity: 15,
    });
  });

  it('sans kcal, convertit les kJ ; une boisson est « pour 100 ml »', () => {
    const product = toPackagedFood(code, {
      product_name: 'Jus',
      product_quantity_unit: 'ml',
      nutriments: { energy_100g: 180 },
    });
    expect(product?.per100g.kcal).toBe(43);
    expect(product?.liquid).toBe(true);
  });

  it('une base collaborative ne se croit pas : valeur hors bornes ou absente = inconnue', () => {
    const product = toPackagedFood(code, {
      product_name: 'Barre',
      serving_quantity: -3,
      nutriments: { 'energy-kcal_100g': 400, proteins_100g: 250, fat_100g: null },
    });
    expect(product?.per100g).toEqual({ kcal: 400, proteinG: null, carbsG: null, fatG: null });
    expect(product?.servingQuantity).toBeNull();
  });

  it('sans énergie lisible, le produit n’est pas utilisable', () => {
    expect(toPackagedFood(code, { product_name: 'Mystère', nutriments: {} })).toBeNull();
    expect(
      toPackagedFood(code, { product_name: 'Faux', nutriments: { 'energy-kcal_100g': 5000 } }),
    ).toBeNull();
    expect(toPackagedFood(code, 'pas un objet')).toBeNull();
  });

  it('les caractères invisibles d’une fiche collaborative ne passent pas', () => {
    expect(
      toPackagedFood(code, {
        product_name: 'Bar\u202Ere\u200B\u0007 chocolat',
        nutriments: { 'energy-kcal_100g': 1 },
      })?.name,
    ).toBe('Bar re chocolat');
  });

  it('sans nom, la marque le remplace, puis un nom générique', () => {
    expect(
      toPackagedFood(code, { brands: 'Marque', nutriments: { 'energy-kcal_100g': 1 } })?.name,
    ).toBe('Marque');
    expect(toPackagedFood(code, { nutriments: { 'energy-kcal_100g': 1 } })?.name).toBe(
      'Produit scanné',
    );
  });
});
