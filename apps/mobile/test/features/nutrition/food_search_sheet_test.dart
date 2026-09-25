import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/utilities/debouncer.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/controllers/meal_editor_controller.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/meal_editor_screen.dart';
import 'package:carlys_mobile/features/nutrition/presentation/utils/meal_editor_state.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/meal_editor/food_result_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_nutrition_repository.dart';
import '../../support/meal_editor_app.dart';
import '../../support/sample_meals.dart';

/// LA FEUILLE « AJOUTER UN ALIMENT » : chercher, choisir, dire combien — et
/// ce qu'elle dit quand la base manque, se tait ou ne répond pas.
///
/// Ce que ces tests protègent, d'abord : la ligne ajoutée porte un UUID né
/// sur l'appareil, qui part tel quel au serveur ; et la mention de la base
/// (licence Etalab) est visible LÀ OÙ L'ON CHERCHE, version comprise.
void main() {
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  FakeNutritionRepository withFoods() =>
      FakeNutritionRepository()
        ..foods.addEntries(searchableFoods.map((f) => MapEntry(f.code, f)));

  Future<void> openSheet(WidgetTester tester) async {
    await showOnScreen(tester, find.text('Ajouter un aliment'));
    await tester.tap(find.text('Ajouter un aliment'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(AppSearchField),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pump(Debouncer.search);
    await tester.pumpAndSettle();
  }

  MealEditorState editorState(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(MealEditorScreen)),
  ).read(mealEditorProvider((mealId: null, day: null))).requireValue;

  testWidgets('chercher, choisir, dire combien : la ligne arrive sous un UUID '
      'de l’appareil, et part telle quelle', (tester) async {
    final nutrition = withFoods();
    await openMealEditor(tester, nutrition, AppRoutes.newMeal());
    await openSheet(tester);

    // Avant la frappe : une invitation, pas une liste vide.
    expect(find.text('Cherche un aliment'), findsOneWidget);

    await search(tester, 'riz');
    // Nom court, nom officiel, calories POUR 100 g, vignette de famille.
    expect(find.byType(FoodResultRow), findsWidgets);
    expect(find.text('Riz basmati'), findsOneWidget);
    expect(find.text('Riz basmati, cuit'), findsOneWidget);
    expect(find.text('125 kcal'), findsOneWidget);
    // La mention de la base, avec sa version et son adresse, en pied de
    // feuille.
    expect(
      find.text(
        'Source : Anses, Table de composition nutritionnelle des aliments '
        'Ciqual (version 2020-07-07), Licence Ouverte Etalab 2.0, '
        'ciqual.anses.fr.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Riz basmati'));
    await tester.pumpAndSettle();
    // La quantité, 100 g par défaut : les valeurs de la table sont pour 100 g.
    expect(find.text('Quantité de Riz basmati'), findsWidgets);
    final field = find.descendant(
      of: find.byType(AppPopupCard),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(field).controller!.text, '100');
    await tester.enterText(field, '150');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    // La feuille s'est refermée ; la ligne est dans la carte.
    expect(find.byType(AppSearchField), findsNothing);
    final line = editorState(tester).lines.single;
    expect(line.foodCode, 990008);
    expect(line.quantityG, 150);
    expect(line.sourceVersion, '2020-07-07');
    expect(line.id, matches(uuidV4));
    // L'aperçu : 125 kcal × 150 / 100, arrondi.
    await showOnScreen(tester, find.byType(AppNutrientTile).first);
    expect(find.text('188'), findsOneWidget);

    await tester.enterText(fieldLabelled('Nom du repas'), 'Riz du midi');
    await tester.pumpAndSettle();
    await showOnScreen(tester, find.text('Ajouter au journal'));
    await tester.tap(find.text('Ajouter au journal'));
    await tester.pumpAndSettle();

    final sent = nutrition.writes.single.write.content as ComposedMealContent;
    expect(sent.components.single.id, line.id);
    expect(sent.components.single.foodCode, 990008);
    expect(sent.components.single.quantityG, 150);
    expect(nutrition.meals.single.kcal, 188);
  });

  testWidgets('une quantité hors bornes ne s’ajoute pas ; renoncer ramène '
      'aux résultats', (tester) async {
    await openMealEditor(tester, withFoods(), AppRoutes.newMeal());
    await openSheet(tester);
    await search(tester, 'poulet');
    await tester.tap(find.text('Poulet'));
    await tester.pumpAndSettle();

    final field = find.descendant(
      of: find.byType(AppPopupCard),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '6000');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('Entre 1 et 5 000 g.'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    // Toujours dans la feuille, les résultats sous les yeux ; rien d'ajouté.
    expect(find.byType(FoodResultRow), findsOneWidget);
    expect(editorState(tester).lines, isEmpty);
  });

  testWidgets('la base pas encore chargée : la feuille le dit, et la saisie '
      'à la main reste possible', (tester) async {
    await openMealEditor(
      tester,
      FakeNutritionRepository(),
      AppRoutes.newMeal(),
    );
    await openSheet(tester);
    await search(tester, 'poulet');

    expect(
      find.text(
        'La base d’aliments arrive bientôt : saisis les valeurs à la main.',
      ),
      findsOneWidget,
    );
    // Rien à attribuer : pas de mention sans valeur de la table.
    expect(find.textContaining('Etalab'), findsNothing);

    await tester.tap(find.text('Saisir à la main'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSearchField), findsNothing);
    // Les cases de saisie sont là.
    expect(tileField('Calories'), findsOneWidget);
  });

  testWidgets('aucun résultat : la feuille le dit, avec la requête', (
    tester,
  ) async {
    await openMealEditor(tester, withFoods(), AppRoutes.newMeal());
    await openSheet(tester);
    await search(tester, 'quinoa');

    expect(find.text('Aucun aliment pour « quinoa »'), findsOneWidget);
    expect(find.textContaining('Etalab'), findsOneWidget);
  });

  testWidgets('hors connexion : la cause juste, et « Réessayer » ramène les '
      'résultats', (tester) async {
    final nutrition = withFoods()
      ..searchFailure = const NetworkException('Serveur injoignable');
    await openMealEditor(tester, nutrition, AppRoutes.newMeal());
    await openSheet(tester);
    await search(tester, 'brocoli');

    expect(find.text('Hors connexion'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('Brocoli'), findsOneWidget);
  });

  testWidgets('une panne : « Recherche indisponible », sans perdre la saisie', (
    tester,
  ) async {
    final nutrition = withFoods()
      ..searchFailure = const ServerException('panne', statusCode: 500);
    await openMealEditor(tester, nutrition, AppRoutes.newMeal());
    await openSheet(tester);
    await search(tester, 'riz');

    expect(find.text('Recherche indisponible'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(AppSearchField),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      'riz',
    );
  });

  testWidgets('320 points, texte doublé : la feuille défile, rien ne déborde, '
      'et chaque résultat reste une cible entière', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await openMealEditor(tester, withFoods(), AppRoutes.newMeal());
    await openSheet(tester);
    await search(tester, 'riz');

    expect(tester.takeException(), isNull);
    final row = find.byType(FoodResultRow).first;
    expect(
      tester.getSize(row).height,
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
    // Le nom officiel se lit en entier, jamais coupé.
    expect(find.text('Galette de riz soufflé, nature'), findsOneWidget);
  });
}
