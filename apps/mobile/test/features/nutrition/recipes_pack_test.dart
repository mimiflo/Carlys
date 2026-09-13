import 'package:carlys_mobile/features/nutrition/data/datasources/recipes_pack.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le pack de recettes embarqué : chargement, intégrité, et surtout
/// EXACTITUDE NUTRITIONNELLE.
///
/// C'est le contenu le plus engageant de l'application : quelqu'un qui suit
/// une cible calorique compte sur ces chiffres. Une recette dont le bilan des
/// macros ne tombe pas est une recette fausse, et elle doit faire rougir la
/// CI plutôt que d'induire en erreur.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetRecipesPackCache);
  tearDown(resetRecipesPackCache);

  test('le pack se charge et chaque recette est complète', () async {
    final recipes = await loadRecipesPack();

    expect(recipes, isNotEmpty);
    for (final recipe in recipes) {
      expect(recipe.title, isNotEmpty, reason: recipe.id);
      expect(recipe.summary, isNotEmpty, reason: recipe.id);
      expect(recipe.minutes, greaterThan(0), reason: recipe.id);
      expect(recipe.kcal, greaterThan(0), reason: recipe.id);
      expect(recipe.ingredients, isNotEmpty, reason: recipe.id);
      expect(recipe.steps, isNotEmpty, reason: recipe.id);
      expect(recipe.steps.length, lessThanOrEqualTo(8), reason: recipe.id);
      expect(recipe.goals, isNotEmpty, reason: recipe.id);
    }
  });

  test('les identifiants sont uniques', () async {
    final recipes = await loadRecipesPack();
    expect(recipes.map((recipe) => recipe.id).toSet().length, recipes.length);
  });

  test('aucun titre en double DANS UN MÊME ONGLET', () async {
    // Des identifiants uniques ne suffisent pas : « Déjeuner & dîner » est UN
    // onglet, et deux recettes écrites séparément y ont porté le même titre.
    // À l'écran, la liste se répétait, ce qui se lit comme un bug. C'est la
    // paire (volet, saveur) qui fait l'onglet, donc c'est elle qui compte.
    final recipes = await loadRecipesPack();
    final parOnglet = <String, List<String>>{};
    for (final recipe in recipes) {
      final onglet = '${recipe.moment.name}/${recipe.saveur?.name ?? ''}';
      parOnglet.putIfAbsent(onglet, () => []).add(recipe.title.toLowerCase());
    }

    for (final entree in parOnglet.entries) {
      final titres = entree.value;
      final doublons = titres.where(
        (titre) => titres.where((autre) => autre == titre).length > 1,
      );
      expect(
        doublons,
        isEmpty,
        reason: 'onglet ${entree.key} : ${doublons.toSet().join(', ')}',
      );
    }
  });

  test(
    'LE BILAN DES MACROS TOMBE : 4/4/9 contre les calories annoncées',
    () async {
      // Protéines et glucides à 4 kcal/g, lipides à 9 : c'est arithmétique, pas
      // une opinion. On tolère 15 % d'écart pour les arrondis et les fibres,
      // pas davantage — au-delà, ce sont les chiffres qui sont faux.
      final recipes = await loadRecipesPack();
      final fautives = <String>[];

      for (final recipe in recipes) {
        final calcule =
            recipe.proteinG * 4 + recipe.carbsG * 4 + recipe.fatG * 9;
        final ecart = (calcule - recipe.kcal).abs() / recipe.kcal;
        if (ecart > 0.15) {
          fautives.add(
            '${recipe.id} : annoncé ${recipe.kcal} kcal, '
            'macros = $calcule kcal (${(ecart * 100).round()} % d’écart)',
          );
        }
      }

      expect(fautives, isEmpty, reason: fautives.join('\n'));
    },
  );

  test('la saveur partage le volet petit-déj, et lui seul', () async {
    final recipes = await loadRecipesPack();

    for (final recipe in recipes) {
      if (recipe.moment == RecipeMoment.petitDejCollation) {
        // Sans saveur, la recette n'apparaîtrait dans aucun des deux onglets,
        // donc nulle part.
        expect(recipe.saveur, isNotNull, reason: recipe.id);
      } else {
        expect(recipe.saveur, isNull, reason: recipe.id);
      }
    }
  });

  test(
    'chaque volet, et chaque saveur, a de quoi remplir son onglet',
    () async {
      final recipes = await loadRecipesPack();

      for (final saveur in RecipeSaveur.values) {
        expect(
          recipes.where(
            (recipe) =>
                recipe.moment == RecipeMoment.petitDejCollation &&
                recipe.saveur == saveur,
          ),
          isNotEmpty,
          reason: 'aucune recette ${saveur.name} au petit-déj',
        );
      }
      expect(
        recipes.where((recipe) => recipe.moment == RecipeMoment.repas),
        isNotEmpty,
      );
    },
  );

  test('les trois objectifs sont servis, et le champ DISCRIMINE', () async {
    final recipes = await loadRecipesPack();

    for (final goal in NutritionGoal.values) {
      expect(
        recipes.where((recipe) => recipe.goals.contains(goal)),
        isNotEmpty,
        reason: 'aucune recette pour ${goal.label}',
      );
    }
    // Si TOUTES les recettes convenaient aux trois objectifs, le champ ne
    // dirait plus rien et le classement de l'écran serait décoratif.
    expect(
      recipes.where(
        (recipe) => recipe.goals.length < NutritionGoal.values.length,
      ),
      isNotEmpty,
      reason: 'toutes les recettes se disent bonnes pour tout',
    );
  });

  test('aucun tiret de ponctuation dans les textes', () async {
    // Même ligne éditoriale que l'Academy : les tirets cadratins font
    // « machine ». Les traits d'union des mots composés restent.
    final recipes = await loadRecipesPack();
    for (final recipe in recipes) {
      final textes = [
        recipe.title,
        recipe.summary,
        ...recipe.ingredients,
        ...recipe.steps,
      ];
      for (final texte in textes) {
        expect(
          texte.contains('—') || texte.contains('–'),
          isFalse,
          reason: '${recipe.id} : « $texte »',
        );
      }
    }
  });

  test(
    'un échec de lecture ne condamne pas les rechargements suivants',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler(
        'flutter/assets',
        (message) async => null,
      );
      await expectLater(loadRecipesPack(), throwsA(isA<Object>()));

      // Le bundle redevient normal : le rechargement doit RÉESSAYER, pas
      // resservir la future en échec restée mémoïsée.
      messenger.setMockMessageHandler('flutter/assets', null);
      expect(await loadRecipesPack(), isNotEmpty);
    },
  );
}
