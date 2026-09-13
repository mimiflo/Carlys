/// Le choix des recettes à montrer, et dans quel ordre.
///
/// Fonction PURE, hors de tout widget : c'est la règle « adaptée au profil »,
/// et elle doit pouvoir être éprouvée sans monter un écran.
library;

import 'entities/nutrition.dart' show NutritionGoal;
import 'entities/recipe.dart';

/// Les recettes d'un volet, celles qui servent l'objectif en tête.
///
/// ON NE CACHE RIEN. Filtrer sur l'objectif viderait des volets entiers et
/// déciderait à la place de la personne : quelqu'un qui prend du muscle a le
/// droit de vouloir une salade. Les recettes qui servent son objectif
/// passent simplement devant, et l'écran les marque ; les autres suivent.
///
/// Le tri est STABLE : à l'intérieur de chaque groupe, l'ordre du pack est
/// conservé. Sans cela, l'ordre changerait d'un affichage à l'autre sans
/// raison visible.
List<Recipe> recipesFor(
  List<Recipe> all, {
  required RecipeMoment moment,
  RecipeSaveur? saveur,
  NutritionGoal? goal,
}) {
  final duVolet = all
      .where((recipe) {
        if (recipe.moment != moment) {
          return false;
        }
        return saveur == null || recipe.saveur == saveur;
      })
      .toList(growable: false);

  if (goal == null) {
    return duVolet;
  }

  return [
    ...duVolet.where((recipe) => recipe.suits(goal)),
    ...duVolet.where((recipe) => !recipe.suits(goal)),
  ];
}
