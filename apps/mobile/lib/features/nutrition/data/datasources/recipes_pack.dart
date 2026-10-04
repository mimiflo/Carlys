/// Chargement du pack de recettes embarqué (`assets/nutrition/recipes.json`).
///
/// Même patron que le pack de l'Academy, et pour les mêmes raisons : c'est un
/// contenu éditorial qui doit s'ouvrir hors ligne.
library;

import '../../../../core/utilities/embedded_pack.dart';
import '../../domain/entities/nutrition.dart' show NutritionGoal;
import '../../domain/entities/recipe.dart';

final _pack = EmbeddedPack<Recipe>(
  asset: 'assets/nutrition/recipes.json',
  listKey: 'recipes',
  parse: _recipe,
  emptyMessage: 'pack de recettes vide',
);

Future<List<Recipe>> loadRecipesPack() => _pack.load();

/// Réservé aux tests, qui vérifient le rechargement.
void resetRecipesPackCache() => _pack.reset();

Recipe _recipe(Map<String, dynamic> json) {
  final id = json['id'] as String;
  final moment = RecipeMoment.values.byName(json['moment'] as String);
  final saveurName = json['saveur'] as String?;
  final saveur = saveurName == null
      ? null
      : RecipeSaveur.values.byName(saveurName);
  // La saveur partage le volet petit-déj/collation : sans elle, la recette
  // n'apparaîtrait dans aucun des deux onglets, donc nulle part.
  if (moment == RecipeMoment.petitDejCollation && saveur == null) {
    throw FormatException('saveur absente pour $id');
  }
  return Recipe(
    id: id,
    moment: moment,
    saveur: saveur,
    title: json['title'] as String,
    summary: json['summary'] as String,
    minutes: (json['minutes'] as num).toInt(),
    kcal: (json['kcal'] as num).toInt(),
    proteinG: (json['proteinG'] as num).toInt(),
    carbsG: (json['carbsG'] as num).toInt(),
    fatG: (json['fatG'] as num).toInt(),
    goals: (json['goals'] as List<dynamic>)
        .cast<String>()
        .map(NutritionGoal.values.byName)
        .toList(growable: false),
    ingredients: (json['ingredients'] as List<dynamic>).cast<String>().toList(
      growable: false,
    ),
    steps: (json['steps'] as List<dynamic>).cast<String>().toList(
      growable: false,
    ),
  );
}
