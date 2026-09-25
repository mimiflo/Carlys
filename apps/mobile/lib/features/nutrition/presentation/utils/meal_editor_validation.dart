/// Les fautes de saisie de l'écran de repas, en fonctions pures.
///
/// Chaque borne est celle du contrat serveur ([MealBounds]) : mieux vaut la
/// dire sous la case qu'encaisser un 400 après l'envoi. Les messages
/// nomment la case, parce que les quatre tuiles de valeurs partagent une
/// seule ligne d'erreur sous leur grille.
library;

import '../../domain/meal_bounds.dart';
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
  });

  final String? name;
  final String? kcal;
  final String? protein;
  final String? carbs;
  final String? fat;
  final String? quantity;

  bool get isEmpty =>
      name == null &&
      kcal == null &&
      protein == null &&
      carbs == null &&
      fat == null &&
      quantity == null;

  /// Les fautes des quatre tuiles de valeurs, dans leur ordre.
  List<String> get values => [?kcal, ?protein, ?carbs, ?fat];
}

MealEditorErrors validateMealEditor(MealEditorState state) {
  final name = state.name.trim().isEmpty ? 'Nomme ton repas.' : null;
  if (state.isComposed) {
    // Les totaux d'un repas composé se calculent sur le serveur : rien à
    // vérifier ici que le nom.
    return MealEditorErrors(name: name);
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
