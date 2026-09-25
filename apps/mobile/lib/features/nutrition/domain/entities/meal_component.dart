/// Les aliments d'un repas COMPOSÉ : ce que le serveur a enregistré, ce que
/// l'appareil envoie, et la ligne qu'on édite entre les deux.
library;

import 'food.dart';

/// Un aliment d'un repas composé, tel que le serveur l'a enregistré.
///
/// `name`, `shortName` et `group` sont l'INSTANTANÉ pris à l'ajout : une
/// nouvelle version de la table ne réécrit pas un repas passé. Les valeurs
/// sont celles DE CE COMPOSANT, pour [quantityG] (pas pour 100 g), arrondies
/// au dixième ; une macro inconnue de la table reste `null`.
class MealComponent {
  const MealComponent({
    required this.id,
    required this.foodCode,
    required this.name,
    required this.shortName,
    required this.quantityG,
    required this.kcal,
    this.group,
    this.sourceVersion,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  /// L'UUID que l'appareil a donné à la ligne, stable d'une correction à
  /// l'autre : c'est lui qui désigne la ligne à GARDER.
  final String id;
  final int foodCode;
  final String name;
  final String shortName;
  final String? group;

  /// La version de la table d'où viennent les valeurs de CETTE ligne.
  final String? sourceVersion;
  final double quantityG;
  final double kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
}

/// Une ligne d'une composition, telle que l'appareil l'ENVOIE : laquelle,
/// quel aliment, combien. Rien d'autre : le nom et les valeurs, le serveur
/// les lit dans la base (ligne neuve) ou dans son instantané (ligne gardée).
class MealComponentInput {
  const MealComponentInput({
    required this.id,
    required this.foodCode,
    required this.quantityG,
  });

  final String id;
  final int foodCode;
  final double quantityG;
}

/// Une ligne EN COURS D'ÉDITION : ce qu'il faut pour l'afficher, l'envoyer,
/// et calculer l'aperçu des totaux.
///
/// Elle porte les valeurs POUR 100 g. Pour un aliment tout juste trouvé dans
/// la base, ce sont celles de la table ; pour une ligne déjà enregistrée,
/// le serveur ne rend que les valeurs de la ligne, pour sa quantité : on en
/// DÉDUIT les valeurs pour 100 g, à l'arrondi du dixième près. L'aperçu est
/// donc un aperçu : le total qui fait foi est celui que le serveur calcule
/// sur son instantané, à l'enregistrement.
class MealLine {
  const MealLine({
    required this.id,
    required this.foodCode,
    required this.name,
    required this.shortName,
    required this.quantityG,
    required this.per100g,
    this.group,
    this.sourceVersion,
  });

  /// La ligne d'un repas déjà enregistré.
  factory MealLine.fromComponent(MealComponent component) {
    final grams = component.quantityG;
    double? per100(double? value) =>
        value == null || grams <= 0 ? null : value * 100 / grams;
    return MealLine(
      id: component.id,
      foodCode: component.foodCode,
      name: component.name,
      shortName: component.shortName,
      group: component.group,
      sourceVersion: component.sourceVersion,
      quantityG: grams,
      per100g: FoodPer100g(
        kcal: grams <= 0 ? 0 : component.kcal * 100 / grams,
        proteinG: per100(component.proteinG),
        carbsG: per100(component.carbsG),
        fatG: per100(component.fatG),
      ),
    );
  }

  /// La ligne d'un aliment choisi dans la base, sous un identifiant NEUF
  /// né sur l'appareil ([id]).
  factory MealLine.fromFood({
    required String id,
    required Food food,
    required double quantityG,
    String? sourceVersion,
  }) {
    return MealLine(
      id: id,
      foodCode: food.code,
      name: food.name,
      shortName: food.shortName,
      group: food.group,
      sourceVersion: sourceVersion,
      quantityG: quantityG,
      per100g: food.per100g,
    );
  }

  final String id;
  final int foodCode;
  final String name;
  final String shortName;
  final String? group;
  final String? sourceVersion;
  final double quantityG;
  final FoodPer100g per100g;

  FoodFamily get family => FoodFamily.fromGroup(group);

  MealLine withQuantity(double grams) => MealLine(
    id: id,
    foodCode: foodCode,
    name: name,
    shortName: shortName,
    group: group,
    sourceVersion: sourceVersion,
    quantityG: grams,
    per100g: per100g,
  );

  MealComponentInput toInput() =>
      MealComponentInput(id: id, foodCode: foodCode, quantityG: quantityG);
}
