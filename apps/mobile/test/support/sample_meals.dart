/// Les repas et les aliments d'EXEMPLE des tests et des captures.
///
/// Un repas composé réaliste — celui de la maquette : 120 g de poulet, 150 g
/// de riz, 50 g de brocoli, 320 g en tout —, un repas saisi à la main, et
/// un repas ancien, noté avant que le moment de la journée existe.
///
/// Les valeurs pour 100 g sont PLAUSIBLES, pas recopiées de la table CIQUAL :
/// ce sont celles du jeu d'essai du serveur (`apps/api/test/fixtures/ciqual`),
/// qui rend 390 kcal, 40 g de protéines, 44 g de glucides et 5 g de lipides
/// pour ce repas — les deux côtés se vérifient donc sur les mêmes nombres.
library;

import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';

const _viandes = 'viandes, œufs, poissons et assimilés';
const _cereales = 'produits céréaliers';
const _vegetaux = 'fruits, légumes, légumineuses et oléagineux';

const pouletCuit = Food(
  code: 990001,
  name: 'Poulet, filet, sans peau, cuit',
  shortName: 'Poulet',
  group: _viandes,
  per100g: FoodPer100g(kcal: 150, proteinG: 29, carbsG: 0, fatG: 3.6),
);

const rizBlancCuit = Food(
  code: 990002,
  name: 'Riz blanc, cuit',
  shortName: 'Riz',
  group: _cereales,
  per100g: FoodPer100g(kcal: 130, proteinG: 2.7, carbsG: 28.6, fatG: 0.3),
);

const brocoliCuit = Food(
  code: 990003,
  name: 'Brocoli, cuit',
  shortName: 'Brocoli',
  group: _vegetaux,
  per100g: FoodPer100g(kcal: 29.5, proteinG: 2.4, carbsG: 2.1, fatG: 0),
);

/// Une galette dont la table ne donne pas les lipides : sa présence rend le
/// total des lipides INCONNU.
const galetteRiz = Food(
  code: 990006,
  name: 'Galette de riz soufflé, nature',
  shortName: 'Galette de riz',
  group: _cereales,
  per100g: FoodPer100g(kcal: 390, proteinG: 8, carbsG: 81),
);

const sampleFoods = [pouletCuit, rizBlancCuit, brocoliCuit, galetteRiz];

/// De quoi remplir une recherche « riz » : des voisins plausibles du riz
/// blanc, dans trois familles (céréales, plats, produits sucrés), pour que
/// la feuille de recherche montre des vignettes différentes.
const searchableFoods = [
  ...sampleFoods,
  Food(
    code: 990007,
    name: 'Riz complet, cuit',
    shortName: 'Riz complet',
    group: _cereales,
    per100g: FoodPer100g(kcal: 145, proteinG: 3.2, carbsG: 30, fatG: 1),
  ),
  Food(
    code: 990008,
    name: 'Riz basmati, cuit',
    shortName: 'Riz basmati',
    group: _cereales,
    per100g: FoodPer100g(kcal: 125, proteinG: 2.9, carbsG: 27.5, fatG: 0.4),
  ),
  Food(
    code: 990009,
    name: 'Riz cantonais, plat préparé',
    shortName: 'Riz cantonais',
    group: 'entrées et plats composés',
    per100g: FoodPer100g(kcal: 165, proteinG: 5.5, carbsG: 24, fatG: 5),
  ),
  Food(
    code: 990010,
    name: 'Riz au lait, dessert',
    shortName: 'Riz au lait',
    group: 'produits sucrés',
    per100g: FoodPer100g(kcal: 130, proteinG: 3.4, carbsG: 22, fatG: 3),
  ),
];

const sampleSource = FoodSource(
  attribution:
      'Source : Anses, Table de composition nutritionnelle des aliments '
      'Ciqual',
  license: 'Licence Ouverte Etalab 2.0',
  url: 'https://ciqual.anses.fr/',
  version: '2020-07-07',
);

const sampleAttribution = FoodAttribution(
  attribution:
      'Source : Anses, Table de composition nutritionnelle des aliments '
      'Ciqual',
  license: 'Licence Ouverte Etalab 2.0',
  url: 'https://ciqual.anses.fr/',
);

/// Une ligne de repas telle que le serveur l'enregistre : les valeurs de
/// l'aliment pour SA quantité, au dixième.
MealComponent componentOf(String id, Food food, double grams) {
  double tenth(double value) => (value * grams / 100 * 10).round() / 10;
  final per100g = food.per100g;
  return MealComponent(
    id: id,
    foodCode: food.code,
    name: food.name,
    shortName: food.shortName,
    group: food.group,
    sourceVersion: '2020-07-07',
    quantityG: grams,
    kcal: tenth(per100g.kcal),
    proteinG: per100g.proteinG == null ? null : tenth(per100g.proteinG!),
    carbsG: per100g.carbsG == null ? null : tenth(per100g.carbsG!),
    fatG: per100g.fatG == null ? null : tenth(per100g.fatG!),
  );
}

/// Le déjeuner de la maquette, composé, avec sa photo.
MealEntry composedLunch({
  required DateTime eatenAt,
  String id = 'repas-compose',
}) {
  return MealEntry(
    id: id,
    name: 'Poulet, riz, brocoli',
    moment: MealMoment.lunch,
    kcal: 390,
    proteinG: 40,
    carbsG: 44,
    fatG: 5,
    quantity: 320,
    quantityUnit: MealQuantityUnit.gram,
    eatenAt: eatenAt.toUtc(),
    computed: true,
    photoUpdatedAt: DateTime.utc(2026, 9, 25, 12, 40),
    components: [
      componentOf('11111111-1111-4111-8111-111111111111', pouletCuit, 120),
      componentOf('22222222-2222-4222-8222-222222222222', rizBlancCuit, 150),
      componentOf('33333333-3333-4333-8333-333333333333', brocoliCuit, 50),
    ],
  );
}

/// Un petit-déjeuner saisi à la main, sans aliment de la base.
MealEntry manualBreakfast({
  required DateTime eatenAt,
  String id = 'repas-saisi',
}) {
  return MealEntry(
    id: id,
    name: 'Skyr, granola, myrtilles',
    moment: MealMoment.breakfast,
    kcal: 380,
    proteinG: 28,
    carbsG: 44,
    fatG: 9,
    quantity: 1,
    quantityUnit: MealQuantityUnit.portion,
    eatenAt: eatenAt.toUtc(),
  );
}

/// Un repas ANCIEN, noté avant que le moment existe : `moment` est nul, et
/// l'écran le propose d'après l'heure.
MealEntry oldMealWithoutMoment({
  required DateTime eatenAt,
  String id = 'repas-ancien',
}) {
  return MealEntry(
    id: id,
    name: 'Omelette, salade verte',
    kcal: 420,
    proteinG: 24,
    eatenAt: eatenAt.toUtc(),
  );
}
