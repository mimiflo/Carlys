import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/meal_editor_controller.dart';
import 'food_search_sheet.dart';

/// « + Ajouter un aliment » : la feuille de recherche (champ, résultats,
/// mention de la base), la quantité en grammes, puis la ligne, déposée par
/// le contrôleur sous un UUID né sur l'appareil.
///
/// Rien ne part au serveur ici : la composition s'envoie à l'enregistrement,
/// et c'est lui qui en calcule les totaux. L'écran en montre l'aperçu.
Future<void> pickFoodForMeal(
  BuildContext context,
  WidgetRef ref,
  MealEditorKey key,
) async {
  final pick = await showFoodSearchSheet(context);
  if (pick == null || !context.mounted) {
    return;
  }
  ref
      .read(mealEditorProvider(key).notifier)
      .addFood(pick.food, pick.grams, pick.source);
}
