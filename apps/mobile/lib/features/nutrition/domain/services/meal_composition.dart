/// L'APERÇU des totaux d'un repas composé, calculé sur l'appareil.
///
/// La même règle que le serveur (`meal-composition.ts`) : chaque aliment
/// vaut « valeur pour 100 g × grammes / 100 », les valeurs s'additionnent,
/// et le total s'arrondit UNE fois, à l'entier, demi vers le haut. Une macro
/// que la table ignore pour UN aliment rend le total inconnu (`null`) :
/// compter un inconnu pour zéro afficherait un total faux avec l'aplomb d'un
/// vrai.
///
/// C'est un APERÇU, et il le reste : l'écran le montre pendant qu'on
/// compose, mais n'envoie jamais ces totaux — le serveur les recalcule en
/// décimal exact sur l'instantané de chaque ligne, et c'est son résultat qui
/// s'enregistre. Les deux peuvent différer d'une unité (les valeurs d'une
/// ligne déjà enregistrée n'arrivent qu'au dixième).
library;

import '../entities/meal_component.dart';

/// Les totaux d'un repas : calories, trois macros, quantité en grammes.
class MealTotals {
  const MealTotals({
    required this.kcal,
    required this.quantityG,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  final int kcal;

  /// `null` : au moins un aliment ne donne pas cette macro.
  final int? proteinG;
  final int? carbsG;
  final int? fatG;

  /// La somme exacte des grammes (deux décimales au plus, comme chaque
  /// ligne).
  final double quantityG;
}

/// Les totaux que le serveur calculera pour [lines].
MealTotals compositionPreview(List<MealLine> lines) {
  var kcal = 0.0;
  var grams = 0.0;
  double? protein = 0;
  double? carbs = 0;
  double? fat = 0;
  double? add(double? total, double? per100g, double quantityG) =>
      total == null || per100g == null
      ? null
      : total + per100g * quantityG / 100;

  for (final line in lines) {
    final per100g = line.per100g;
    kcal += per100g.kcal * line.quantityG / 100;
    grams += line.quantityG;
    protein = add(protein, per100g.proteinG, line.quantityG);
    carbs = add(carbs, per100g.carbsG, line.quantityG);
    fat = add(fat, per100g.fatG, line.quantityG);
  }
  return MealTotals(
    kcal: roundHalfUp(kcal),
    proteinG: protein == null ? null : roundHalfUp(protein),
    carbsG: carbs == null ? null : roundHalfUp(carbs),
    fatG: fat == null ? null : roundHalfUp(fat),
    // Deux décimales au plus par ligne : on retire le bruit du flottant
    // (0,1 + 0,2) sans rien arrondir de ce qui a été saisi.
    quantityG: (grams * 100).roundToDouble() / 100,
  );
}

/// Arrondi à l'entier, demi vers le haut, comme le serveur.
///
/// En flottant, une somme qui vaut 12,5 peut sortir à 12,499 999 999 : le
/// millionième ajouté ramène ce vrai demi du bon côté. Il ne peut faire
/// basculer qu'une valeur à moins d'un millionième d'un demi, écart qu'aucun
/// aperçu ne distingue.
int roundHalfUp(double value) => (value + 0.5 + 1e-6).floor();
