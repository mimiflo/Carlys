/// Les recettes Carlys : contenu ÉDITORIAL embarqué, comme le pack de
/// l'Academy, et pas une donnée serveur. Une recette se lit en cuisine, où le
/// réseau est souvent absent : elle voyage donc avec l'application.
library;

import 'nutrition.dart' show NutritionGoal;

/// Les deux volets de la catégorie Recettes.
///
/// L'ordre est celui de l'écran : ce qu'on mange en premier dans la journée
/// d'abord.
enum RecipeMoment {
  petitDejCollation('Petit-déj & collation'),
  repas('Déjeuner & dîner');

  const RecipeMoment(this.label);

  final String label;
}

/// Sucré ou salé.
///
/// Ne concerne QUE le volet petit-déj et collation, où le partage sucré/salé
/// est la première question qu'on se pose. Un déjeuner n'a pas de saveur
/// déclarée : la trancher n'apporterait rien à qui cherche un plat.
enum RecipeSaveur {
  sucre('Sucré'),
  sale('Salé');

  const RecipeSaveur(this.label);

  final String label;
}

/// Une recette : de quoi décider, puis cuisiner.
class Recipe {
  const Recipe({
    required this.id,
    required this.moment,
    required this.title,
    required this.summary,
    required this.minutes,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.goals,
    required this.ingredients,
    required this.steps,
    this.saveur,
  });

  final String id;
  final RecipeMoment moment;

  /// Non nulle pour [RecipeMoment.petitDejCollation], nulle pour un repas.
  final RecipeSaveur? saveur;

  final String title;

  /// Une phrase : ce que la recette apporte, jamais « délicieux et sain ».
  final String summary;

  /// Temps de préparation total, en minutes.
  final int minutes;

  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;

  /// Les objectifs auxquels cette recette convient VRAIMENT. Une liste vide
  /// serait un aveu d'ignorance ; les trois partout viderait le champ de son
  /// sens. Le pack est contrôlé sur ce point.
  final List<NutritionGoal> goals;

  final List<String> ingredients;
  final List<String> steps;

  /// Part de la cible calorique du jour que représente cette recette, en
  /// pourcentage entier.
  ///
  /// Null tant que le profil métabolique est incomplet : sans cible, ce
  /// rapport n'existe pas, et en inventer un serait pire que de se taire.
  int? shareOfTargetPercent(int? targetKcal) {
    if (targetKcal == null || targetKcal <= 0) {
      return null;
    }
    return (kcal * 100 / targetKcal).round();
  }

  /// La recette sert-elle l'objectif de la personne ?
  bool suits(NutritionGoal? goal) => goal != null && goals.contains(goal);
}
