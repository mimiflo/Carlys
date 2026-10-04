import { baseFoodWord, closestFoodQuery } from './closest-food-query';

describe('closestFoodQuery', () => {
  it('l’aliment d’abord, les liaisons tombent, chaque mot classe', () => {
    expect(closestFoodQuery('Sauce tomate, avec viande hachée')).toEqual({
      heads: ['sauce', 'tomate', 'viande'],
      terms: [
        { word: 'sauce', base: 'sauce', exact: 1 },
        { word: 'tomate', base: 'tomate', exact: 2 },
        { word: 'viande', base: 'viande', exact: 2 },
        { word: 'hachee', base: 'hachee', exact: 2 },
      ],
      cooked: false,
    });
  });

  it('un mot de préparation classe ; il ne nomme l’aliment que s’il est seul', () => {
    const edamame = closestFoodQuery('Edamame, cuits, frais');
    expect(edamame?.heads).toEqual(['edamame']);
    expect(edamame?.cooked).toBe(true);
    expect(closestFoodQuery('Tranche de jambon')?.heads).toEqual(['jambon']);
    expect(closestFoodQuery('Frites')?.heads).toEqual(['frite']);
  });

  it('un chiffre ne nomme jamais l’aliment : « 1 pomme » cherche la pomme', () => {
    expect(closestFoodQuery('1 pomme')?.heads).toEqual(['pomme']);
    expect(closestFoodQuery('2 3')).toBeNull();
  });

  it('le pluriel du nom ne compte pas double, sauf « pâtes » ; celui des autres mots, si', () => {
    expect(closestFoodQuery('Oeufs brouillés')?.terms).toEqual([
      { word: 'oeufs', base: 'oeuf', exact: 1 },
      { word: 'brouilles', base: 'brouille', exact: 2 },
    ]);
    expect(closestFoodQuery('Pâtes, cuites')?.terms[0]).toEqual({
      word: 'pates',
      base: 'pate',
      exact: 2,
    });
  });

  it('formes de base : « pois » et « riz » restent ce qu’ils sont', () => {
    expect(['haricots', 'pois', 'riz', 'oeufs', 'choux'].map(baseFoodWord)).toEqual([
      'haricot',
      'pois',
      'riz',
      'oeuf',
      'chou',
    ]);
  });

  it('grillé, poêlé, rôti : cuit ; « cru » ne l’est pas', () => {
    expect(closestFoodQuery('Poulet, filet, grillé')?.cooked).toBe(true);
    expect(closestFoodQuery('Saumon, cru')?.cooked).toBe(false);
  });

  it('l’anglais qui échappe au modèle est traduit avant la recherche', () => {
    expect(closestFoodQuery('Lettuce, cuit')?.heads).toEqual(['salade']);
    expect(closestFoodQuery('Oatmeal, cuit')?.heads).toEqual(['flocon', 'avoine']);
    expect(closestFoodQuery('Mashed potatoes')?.heads).toEqual(['puree', 'pomme', 'terre']);
  });

  it('rien qui nomme un aliment : null', () => {
    expect(closestFoodQuery('!!')).toBeNull();
    expect(closestFoodQuery('de la, avec')).toBeNull();
  });

  it('six mots au plus', () => {
    expect(closestFoodQuery('ab bc cd de ef fg gh hi')?.terms).toHaveLength(6);
  });
});
