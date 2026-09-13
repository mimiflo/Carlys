/// Providers de la catégorie Recettes : le pack embarqué, et ce qu'il faut
/// du profil pour l'adapter.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/recipes_pack.dart';
import '../../domain/entities/nutrition.dart';
import '../../domain/entities/recipe.dart';
import 'nutrition_controllers.dart';

/// Le pack embarqué. Sans `autoDispose` : le contenu ne change jamais en
/// cours de session, le relire à chaque retour sur l'écran serait du travail
/// pour rien.
final recipesPackProvider = FutureProvider<List<Recipe>>((ref) {
  return loadRecipesPack();
});

/// L'objectif alimentaire de la personne, ou `null` tant que son profil est
/// incomplet.
///
/// Lu depuis le rapport métabolique, seul écrivain de cette donnée. `null`
/// n'est pas une panne : c'est « on ne sait pas encore », et l'écran le
/// traite en n'affichant simplement aucune adaptation.
final nutritionGoalProvider = Provider.autoDispose<NutritionGoal?>((ref) {
  return ref.watch(metabolismReportProvider).valueOrNull?.profile.goal;
});

/// La cible calorique du jour, ou `null` si le profil ne permet pas de la
/// calculer. Sert à dire ce qu'une recette pèse dans la journée.
final targetKcalProvider = Provider.autoDispose<int?>((ref) {
  return ref
      .watch(metabolismReportProvider)
      .valueOrNull
      ?.metabolism
      ?.targetKcal;
});
