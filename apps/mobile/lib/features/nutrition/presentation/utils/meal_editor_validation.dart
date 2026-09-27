/// Les fautes de saisie de l'écran de repas, en fonctions pures.
///
/// Chaque borne est celle du contrat serveur ([MealBounds]) : mieux vaut la
/// dire sous la case qu'encaisser un 400 après l'envoi. Les messages
/// nomment la case, parce que les quatre tuiles de valeurs partagent une
/// seule ligne d'erreur sous leur grille.
library;

import '../../../../core/utilities/formatting.dart';
import '../../domain/meal_bounds.dart';
import '../../domain/services/meal_composition.dart';
import 'meal_editor_state.dart';

/// Les fautes d'un état, case par case ; toutes `null` si l'état peut
/// s'enregistrer.
class MealEditorErrors {
  const MealEditorErrors({
    this.name,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.quantity,
    this.composition,
  });

  final String? name;
  final String? kcal;
  final String? protein;
  final String? carbs;
  final String? fat;
  final String? quantity;

  /// Les TOTAUX d'un repas composé sortent des bornes d'un repas : la phrase
  /// que le serveur opposerait, dite avant l'envoi.
  final String? composition;

  bool get isEmpty =>
      name == null &&
      kcal == null &&
      protein == null &&
      carbs == null &&
      fat == null &&
      quantity == null &&
      composition == null;

  /// Les fautes des quatre tuiles de valeurs, dans leur ordre.
  List<String> get values => [?kcal, ?protein, ?carbs, ?fat];
}

MealEditorErrors validateMealEditor(MealEditorState state) {
  final name = state.name.trim().isEmpty ? 'Nomme ton repas.' : null;
  if (state.isComposed) {
    // Les totaux se calculent sur le serveur, qui les BORNE comme une saisie
    // à la main. L'aperçu calculé ici est le même (`compositionPreview`) :
    // 1 500 g d'huile au lieu de 150 (13 500 kcal), ou de l'eau seule
    // (0 kcal), partaient pour un refus que l'écran traduisait en
    // « réessaie dans un instant ». Réessayer n'y changeait rien.
    return MealEditorErrors(
      name: name,
      composition: compositionBoundsError(state.totals),
    );
  }
  return MealEditorErrors(
    name: name,
    kcal: _kcalError(state.kcalText),
    protein: _macroError('Protéines', state.proteinText),
    carbs: _macroError('Glucides', state.carbsText),
    fat: _macroError('Lipides', state.fatText),
    quantity: _quantityError(state.quantityText),
  );
}

/// Ce que dit la notice d'un envoi refusé AVANT de partir.
///
/// Un repas SAISI a ses fautes dans ses cases, en rouge. Un repas COMPOSÉ
/// n'a pas de case à ses valeurs : dire « il manque quelque chose, vérifie
/// les cases en rouge » envoyait chercher ce qui n'existe pas — rien ne
/// manque, aucune case n'est rouge. La phrase qui bloque est dite telle
/// quelle, précédée du nom s'il manque aussi.
String invalidMealNotice(MealEditorErrors errors) {
  final composition = errors.composition;
  if (composition == null) {
    return 'Il manque quelque chose : vérifie les cases signalées en rouge.';
  }
  final name = errors.name;
  return name == null ? composition : '$name $composition';
}

/// La phrase du serveur pour des totaux hors des bornes d'un repas
/// (`assertWithinMealBounds`, `meal-composer.ts`), ou `null`.
String? compositionBoundsError(MealTotals totals) {
  if (totals.kcal < MealBounds.kcalMin) {
    return 'Cette composition fait moins d’une kilocalorie : ajoute un '
        'aliment ou augmente les quantités.';
  }
  if (totals.kcal > MealBounds.kcalMax) {
    return 'Cette composition dépasse '
        '${formatThousands(MealBounds.kcalMax)} kcal, la limite d’un '
        'repas : vérifie les quantités.';
  }
  for (final (grams, label) in [
    (totals.proteinG, 'protéines'),
    (totals.carbsG, 'glucides'),
    (totals.fatG, 'lipides'),
  ]) {
    if (grams != null && grams > MealBounds.macroMaxG) {
      return 'Cette composition dépasse '
          '${formatThousands(MealBounds.macroMaxG)} g de $label, la limite '
          'd’un repas : vérifie les quantités.';
    }
  }
  if (totals.quantityG > MealBounds.quantityMax) {
    return 'Cette composition dépasse '
        '${formatDecimal(MealBounds.quantityMax, decimals: 2)} g au total : '
        'répartis-la en plusieurs repas.';
  }
  return null;
}

String? _kcalError(String raw) {
  final kcal = int.tryParse(raw.trim());
  if (kcal == null || kcal < MealBounds.kcalMin || kcal > MealBounds.kcalMax) {
    return 'Calories : entre 1 et 10 000.';
  }
  return null;
}

/// Vide n'est PAS zéro : c'est « on ne sait pas », et le serveur accepte
/// l'absence.
String? _macroError(String label, String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return null;
  }
  final grams = int.tryParse(text);
  if (grams == null || grams < 0 || grams > MealBounds.macroMaxG) {
    return '$label : entre 0 et 1 000 g.';
  }
  return null;
}

String? _quantityError(String raw) {
  if (raw.trim().isEmpty) {
    return null;
  }
  final quantity = _twoDecimals(raw);
  if (quantity == null ||
      quantity < MealBounds.quantityMin ||
      quantity > MealBounds.quantityMax) {
    return 'Entre 0,01 et 9 999,99.';
  }
  return null;
}

/// Un nombre à DEUX décimales au plus, ou `null` : le serveur refuse une
/// troisième (`maxDecimalPlaces: 2`), et l'arrondir en silence
/// enregistrerait autre chose que ce qui est écrit.
double? _twoDecimals(String raw) {
  final text = raw.trim();
  return _decimal.hasMatch(text) ? parseDecimalInput(text) : null;
}

final RegExp _decimal = RegExp(r'^\d+([.,]\d{1,2})?$');

/// La faute d'une quantité d'aliment saisie dans la popup de correction,
/// ou `null` si elle convient (1 à 5 000 g).
String? componentQuantityError(String raw) {
  final grams = _twoDecimals(raw);
  if (grams == null ||
      grams < MealBounds.componentMinG ||
      grams > MealBounds.componentMaxG) {
    return 'Entre 1 et 5 000 g.';
  }
  return null;
}
