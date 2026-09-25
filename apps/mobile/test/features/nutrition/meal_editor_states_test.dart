import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/meal_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_nutrition_repository.dart';
import '../../support/meal_editor_app.dart';
import '../../support/sample_meals.dart';

/// Les ÉTATS de l'écran de repas : sa lecture qui échoue, son envoi qui
/// échoue, sa suppression, ses fautes de saisie, et sa tenue en grand
/// texte. Un écran qui parle au serveur doit dire ce qu'il advient de
/// chaque geste — et ne jamais perdre en silence ce qu'on a saisi.
void main() {
  DateTime yesterdayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - 1, hour, minute);
  }

  FakeNutritionRepository withLunch() => FakeNutritionRepository()
    ..foods.addEntries(sampleFoods.map((f) => MapEntry(f.code, f)))
    ..meals.add(composedLunch(eatenAt: yesterdayAt(12, 30)));

  Future<void> tapText(WidgetTester tester, String text) async {
    // D'abord laisser finir ce qu'une saisie a lancé : le champ qui prend
    // le focus fait défiler la page jusqu'à lui.
    await tester.pumpAndSettle();
    await showOnScreen(tester, find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  group('la lecture du repas', () {
    testWidgets('introuvable : l’écran le dit, et ramène au journal', (
      tester,
    ) async {
      await openMealEditor(
        tester,
        FakeNutritionRepository(),
        AppRoutes.meal('supprime-ailleurs'),
      );

      expect(find.text('Ce repas n’est plus là'), findsOneWidget);
      // Aucune corbeille sur un repas qu'on n'a pas pu lire.
      expect(find.byTooltip('Supprimer ce repas'), findsNothing);

      await tester.tap(find.text('Retour au journal'));
      await tester.pumpAndSettle();
      expect(find.byType(MealEditorScreen), findsNothing);
    });

    testWidgets('hors connexion : la cause juste, pas une panne', (
      tester,
    ) async {
      final nutrition = withLunch()
        ..mealReadFailure = const NetworkException('Serveur injoignable');
      await openMealEditor(tester, nutrition, AppRoutes.meal('repas-compose'));

      expect(find.text('Hors connexion'), findsOneWidget);
    });

    testWidgets('une panne se réessaie, et le repas revient', (tester) async {
      final nutrition = withLunch()
        ..mealReadFailure = const ServerException('panne', statusCode: 500);
      await openMealEditor(tester, nutrition, AppRoutes.meal('repas-compose'));

      expect(find.text('Repas indisponible'), findsOneWidget);

      nutrition.mealReadFailure = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier ce repas'), findsOneWidget);
      expect(find.text('Poulet'), findsOneWidget);
    });
  });

  group('l’enregistrement', () {
    testWidgets('une saisie fautive se signale sous les cases, rien ne part', (
      tester,
    ) async {
      final nutrition = FakeNutritionRepository();
      await openMealEditor(tester, nutrition, AppRoutes.newMeal());

      // Rien de signalé tant qu'on n'a pas tenté d'enregistrer.
      expect(find.text('Nomme ton repas.'), findsNothing);

      await tester.enterText(tileField('Protéines'), '2000');
      await tapText(tester, 'Ajouter au journal');

      expect(find.text('Nomme ton repas.'), findsOneWidget);
      expect(
        find.text(
          'Calories : entre 1 et 10 000. Protéines : entre 0 et 1 000 g.',
        ),
        findsOneWidget,
      );
      expect(nutrition.writes, isEmpty);
      expect(find.byType(MealEditorScreen), findsOneWidget);
    });

    testWidgets('au lecteur d’écran, chaque case fautive se dit invalide, '
        'avec sa faute', (tester) async {
      final semantics = tester.ensureSemantics();
      await openMealEditor(
        tester,
        FakeNutritionRepository(),
        AppRoutes.newMeal(),
      );
      await tester.enterText(fieldLabelled('Nom du repas'), 'Test');
      await tester.enterText(tileField('Calories'), '0');
      await tapText(tester, 'Ajouter au journal');

      SemanticsData tile(String label) =>
          tester.getSemantics(tileField(label)).getSemanticsData();
      expect(
        tile('Calories').validationResult,
        SemanticsValidationResult.invalid,
      );
      expect(tile('Calories').hint, 'Calories : entre 1 et 10 000.');
      expect(
        tile('Protéines').validationResult,
        isNot(SemanticsValidationResult.invalid),
      );
      // La phrase sous la grille est pour les yeux : elle ne se lit pas une
      // seconde fois.
      expect(
        find.bySemanticsLabel('Calories : entre 1 et 10 000.'),
        findsNothing,
      );
      semantics.dispose();
    });

    testWidgets('un échec du serveur : le message, et RIEN de perdu', (
      tester,
    ) async {
      final nutrition = FakeNutritionRepository()
        ..writeFailure = const ServerException('panne', statusCode: 500);
      await openMealEditor(tester, nutrition, AppRoutes.newMeal());
      await tester.enterText(find.byType(TextField).first, 'Salade niçoise');
      await tester.enterText(tileField('Calories'), '520');

      await tapText(tester, 'Ajouter au journal');

      expect(
        find.text('Ça n’a pas fonctionné. Réessaie dans un instant.'),
        findsOneWidget,
      );
      // L'écran reste, avec ce qui a été saisi.
      expect(find.byType(MealEditorScreen), findsOneWidget);
      expect(find.text('Salade niçoise'), findsOneWidget);
      expect(nutrition.meals, isEmpty);

      // Le second essai part sous le MÊME identifiant : si le premier avait
      // en fait abouti, le serveur ne ferait pas de doublon.
      await tapText(tester, 'Ajouter au journal');

      expect(nutrition.meals, hasLength(1));
      expect(nutrition.writes, hasLength(2));
      expect(nutrition.writes.first.id, nutrition.writes.last.id);
      expect(find.byType(MealEditorScreen), findsNothing);
    });

    testWidgets('hors connexion : la consigne qu’on peut suivre', (
      tester,
    ) async {
      final nutrition = withLunch()
        ..writeFailure = const NetworkException('Serveur injoignable');
      await openMealEditor(tester, nutrition, AppRoutes.meal('repas-compose'));

      await tapText(tester, 'Enregistrer la modification');

      expect(find.textContaining('Hors connexion'), findsOneWidget);
      expect(find.byType(MealEditorScreen), findsOneWidget);
    });
  });

  group('la suppression', () {
    testWidgets('renoncée : le repas reste', (tester) async {
      final nutrition = withLunch();
      await openMealEditor(tester, nutrition, AppRoutes.meal('repas-compose'));

      await tester.tap(find.byTooltip('Supprimer ce repas'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer ce repas ?'), findsOneWidget);

      await tester.tap(find.text('Garder ce repas'));
      await tester.pumpAndSettle();

      expect(nutrition.meals, hasLength(1));
      expect(find.byType(MealEditorScreen), findsOneWidget);
    });

    testWidgets('confirmée : le repas part, retour au journal', (tester) async {
      final nutrition = withLunch();
      await openMealEditor(tester, nutrition, AppRoutes.meal('repas-compose'));

      // Le bouton du bas, cette fois : les deux portes posent la question.
      await tapText(tester, 'Supprimer ce repas');
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(nutrition.meals, isEmpty);
      expect(find.byType(MealEditorScreen), findsNothing);
      expect(find.text('Repas supprimé.'), findsOneWidget);
    });

    testWidgets('en échec : le message, et le repas reste à l’écran', (
      tester,
    ) async {
      final nutrition = withLunch()
        ..writeFailure = const ServerException('panne', statusCode: 500);
      await openMealEditor(tester, nutrition, AppRoutes.meal('repas-compose'));

      await tester.tap(find.byTooltip('Supprimer ce repas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(nutrition.meals, hasLength(1));
      expect(find.byType(MealEditorScreen), findsOneWidget);
      expect(
        find.text('Ça n’a pas fonctionné. Réessaie dans un instant.'),
        findsOneWidget,
      );
    });
  });

  group('les portes d’entrée du journal', () {
    testWidgets('toucher un repas l’ouvre ; « Ajouter » en ouvre un neuf', (
      tester,
    ) async {
      final now = DateTime.now();
      final noon = DateTime(now.year, now.month, now.day, 12);
      final nutrition = FakeNutritionRepository()
        ..meals.add(manualBreakfast(eatenAt: noon.isAfter(now) ? now : noon));
      await pumpMealApp(tester, nutrition);

      await tester.tap(find.text('Skyr, granola, myrtilles'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier ce repas'), findsOneWidget);
      expect(
        tester.widget<TextField>(tileField('Calories')).controller!.text,
        '380',
      );

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un repas'));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau repas'), findsOneWidget);
    });
  });

  group('en grand texte, sur 320 points', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.platformDispatcher.textScaleFactorTestValue = 2;
    });

    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .clearTextScaleFactorTestValue();
    });

    for (final (nom, location) in [
      ('un repas composé', AppRoutes.meal('repas-compose')),
      ('un repas neuf', AppRoutes.newMeal()),
    ]) {
      testWidgets('$nom : rien ne déborde, du haut au bas de la page', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(960, 1920);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await openMealEditor(tester, withLunch(), location);
        // Un débordement est une erreur de rendu : le test tomberait ici.
        await showOnScreen(tester, find.byType(AppCtaButton));
        expect(tester.takeException(), isNull);
        expect(find.byType(AppNutrientTile), findsNWidgets(4));
      });
    }
  });
}
