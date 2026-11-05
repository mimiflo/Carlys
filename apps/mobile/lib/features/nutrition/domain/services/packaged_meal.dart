import 'package:characters/characters.dart';

import '../entities/nutrition.dart';
import '../meal_bounds.dart';

/// Les valeurs d'une quantité de [food] : la règle de trois sur les valeurs
/// pour 100, arrondie comme le journal les garde (des entiers). Une macro
/// inconnue du produit reste inconnue — jamais « 0 g ».
({int kcal, int? proteinG, int? carbsG, int? fatG}) packagedAmounts(
  PackagedFood food,
  double quantity,
) {
  int? of(double? per100) =>
      per100 == null ? null : (per100 * quantity / 100).round();
  return (
    kcal: of(food.per100g.kcal)!,
    proteinG: of(food.per100g.proteinG),
    carbsG: of(food.per100g.carbsG),
    fatG: of(food.per100g.fatG),
  );
}

/// Le repas qu'ajoute un scan : le nom du produit (et sa marque), [quantity]
/// grammes — ou millilitres d'une boisson —, mangé à [eatenAt].
MealWrite packagedMeal(PackagedFood food, double quantity, DateTime eatenAt) {
  final amounts = packagedAmounts(food, quantity);
  final brand = food.brand;
  final name =
      brand == null || food.name.toLowerCase().contains(brand.toLowerCase())
      ? food.name
      : '${food.name} · $brand';
  return MealWrite(
    // Borné comme tout nom de repas : la marque ne fait pas refuser l'envoi.
    name: _bounded(name),
    eatenAt: eatenAt,
    moment: MealMoment.suggestFor(eatenAt.toLocal()),
    content: ManualMealContent(
      kcal: amounts.kcal,
      proteinG: amounts.proteinG,
      carbsG: amounts.carbsG,
      fatG: amounts.fatG,
      quantity: quantity,
      quantityUnit: food.liquid
          ? MealQuantityUnit.milliliter
          : MealQuantityUnit.gram,
    ),
  );
}

/// Au plus [MealBounds.nameMaxLength] unités UTF-16 (la mesure du serveur),
/// coupées entre deux caractères PERÇUS : un emoji, son teint compris,
/// entre entier ou pas du tout.
String _bounded(String name) {
  if (name.length <= MealBounds.nameMaxLength) return name;
  final kept = StringBuffer();
  for (final character in name.characters) {
    if (kept.length + character.length > MealBounds.nameMaxLength) break;
    kept.write(character);
  }
  return kept.toString().trimRight();
}
