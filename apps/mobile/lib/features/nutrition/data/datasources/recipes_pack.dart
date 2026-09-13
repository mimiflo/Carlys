/// Chargement du pack de recettes embarqué (`assets/nutrition/recipes.json`).
///
/// Même patron que le pack de l'Academy, et pour les mêmes raisons : c'est un
/// contenu éditorial qui doit s'ouvrir hors ligne.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/entities/nutrition.dart' show NutritionGoal;
import '../../domain/entities/recipe.dart';

/// C'est le RÉSULTAT qui est mémoïsé, jamais la future : une future ne
/// s'achève que dans la zone où elle est née.
List<Recipe>? _recipes;
Future<List<Recipe>>? _loading;

Future<List<Recipe>> loadRecipesPack() async {
  final cached = _recipes;
  if (cached != null) {
    return cached;
  }
  try {
    final recipes = await (_loading ??= _read());
    _recipes = recipes;
    return recipes;
  } finally {
    // Échec : on ne mémoïse JAMAIS la future en erreur, sinon tout
    // rechargement rejouerait l'échec à jamais.
    _loading = null;
  }
}

Future<List<Recipe>> _read() async {
  // `load` + `utf8.decode`, jamais `loadString` : au-delà de 50 Kio ce
  // dernier délègue le décodage à un isolat, qui ne s'achève pas sous
  // l'horloge simulée d'un test de widget.
  final data = await rootBundle.load('assets/nutrition/recipes.json');
  final raw = utf8.decode(Uint8List.sublistView(data));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final recipes = (decoded['recipes'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map(_recipe)
      .toList(growable: false);
  if (recipes.isEmpty) {
    throw const FormatException('pack de recettes vide');
  }
  return recipes;
}

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

/// Réservé aux tests, qui vérifient le rechargement.
void resetRecipesPackCache() {
  _recipes = null;
  _loading = null;
}
