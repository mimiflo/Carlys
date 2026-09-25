import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/controllers/meal_editor_controller.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/meal_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_nutrition_repository.dart';
import '../../support/meal_editor_app.dart';
import '../../support/sample_meals.dart';

/// L'ÉCRAN « AJOUTER / MODIFIER CE REPAS » (maquette du 25 septembre 2026) :
/// ajouter à la main, corriger un repas composé, et ce que chaque geste
/// envoie au serveur.
///
/// Ce que ces tests protègent, d'abord : un repas composé ne se corrige pas
/// à la main (ses valeurs se LISENT), et ses lignes partent sans aucun
/// total — le serveur les refuserait.
void main() {
  /// Hier, à midi et demi : un instant toujours PASSÉ, quelle que soit
  /// l'heure où le test tourne (un repas du futur est refusé).
  DateTime yesterdayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - 1, hour, minute);
  }

  Finder unitPill(String label) => find.descendant(
    of: find.byType(AppChoicePills<MealQuantityUnit>),
    matching: find.text(label),
  );

  AppIconChoiceTile selectedMoment(WidgetTester tester) => tester
      .widgetList<AppIconChoiceTile>(find.byType(AppIconChoiceTile))
      .singleWhere((tile) => tile.selected);

  Future<void> tapText(WidgetTester tester, String text) async {
    // D'abord laisser finir ce qu'une saisie a lancé : le champ qui prend
    // le focus fait défiler la page jusqu'à lui.
    await tester.pumpAndSettle();
    await showOnScreen(tester, find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  group('un repas neuf, saisi à la main', () {
    testWidgets('il part au journal, et l’écran se referme', (tester) async {
      final nutrition = FakeNutritionRepository();
      await openMealEditor(tester, nutrition, AppRoutes.newMeal());

      expect(find.text('Nouveau repas'), findsOneWidget);
      // Rien à supprimer : ni corbeille, ni bouton rouge.
      expect(find.byTooltip('Supprimer ce repas'), findsNothing);
      expect(find.text('Supprimer ce repas'), findsNothing);

      await tester.enterText(fieldLabelled('Nom du repas'), 'Skyr, granola');
      await tester.enterText(tileField('Calories'), '380');
      await tester.enterText(tileField('Protéines'), '28');
      await tester.pumpAndSettle();
      await showOnScreen(tester, unitPill('portion'));
      await tester.tap(unitPill('portion'));
      await tester.pumpAndSettle();
      expect(find.text('Quantité (portions)'), findsOneWidget);
      await tester.enterText(fieldLabelled('Quantité (portions)'), '1,5');
      await tapText(tester, 'Ajouter au journal');

      final meal = nutrition.meals.single;
      expect(meal.name, 'Skyr, granola');
      expect(meal.kcal, 380);
      expect(meal.proteinG, 28);
      expect(meal.carbsG, isNull, reason: 'vide veut dire inconnu');
      expect(meal.quantity, 1.5);
      expect(meal.quantityUnit, MealQuantityUnit.portion);
      expect(meal.computed, isFalse);
      // L'écran s'est refermé sur le journal, qui montre le repas.
      expect(find.byType(MealEditorScreen), findsNothing);
      expect(find.text('Repas ajouté au journal.'), findsOneWidget);
    });

    testWidgets('le moment se propose d’après l’heure, et se change', (
      tester,
    ) async {
      final nutrition = FakeNutritionRepository();
      await openMealEditor(tester, nutrition, AppRoutes.newMeal());

      final proposed = MealMoment.suggestFor(DateTime.now());
      expect(selectedMoment(tester).label, proposed.label);

      final other = MealMoment.values.firstWhere((m) => m != proposed);
      await showOnScreen(
        tester,
        find.widgetWithText(AppIconChoiceTile, other.label),
      );
      await tester.tap(find.widgetWithText(AppIconChoiceTile, other.label));
      await tester.pumpAndSettle();
      expect(selectedMoment(tester).label, other.label);

      await tester.enterText(fieldLabelled('Nom du repas'), 'Pomme');
      await tester.enterText(tileField('Calories'), '80');
      await tapText(tester, 'Ajouter au journal');

      expect(nutrition.meals.single.moment, other);
    });

    testWidgets('un jour passé du journal : le repas y est daté, à midi', (
      tester,
    ) async {
      final nutrition = FakeNutritionRepository();
      final day = yesterdayAt(0, 0);
      await openMealEditor(tester, nutrition, AppRoutes.newMeal(day: day));

      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('12h00'), findsOneWidget);
      expect(selectedMoment(tester).label, 'Déjeuner');
    });
  });

  group('un repas composé', () {
    FakeNutritionRepository withLunch() => FakeNutritionRepository()
      ..foods.addEntries(sampleFoods.map((f) => MapEntry(f.code, f)))
      ..meals.add(composedLunch(eatenAt: yesterdayAt(12, 30)));

    testWidgets('ses valeurs et sa quantité se LISENT, calculées', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openMealEditor(
        tester,
        withLunch(),
        AppRoutes.meal('repas-compose'),
      );

      expect(find.text('Modifier ce repas'), findsOneWidget);
      expect(find.text('AJUSTE LES DÉTAILS'), findsOneWidget);
      // Aucune case dans les tuiles : le serveur calcule.
      await showOnScreen(tester, find.byType(AppNutrientTile).first);
      expect(
        find.descendant(
          of: find.byType(AppNutrientTile),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Calories : 390 kcal'), findsOneWidget);
      expect(find.bySemanticsLabel('Protéines : 40 g'), findsOneWidget);
      // La quantité : la somme des aliments, en lecture seule, en grammes.
      final quantity = tester.widget<TextField>(
        fieldLabelled('Quantité (grammes)'),
      );
      expect(quantity.readOnly, isTrue);
      expect(quantity.controller!.text, '320');
      // Le nom passe à la ligne plutôt que de se couper sous le crayon.
      final name = tester.widget<TextField>(fieldLabelled('Nom du repas'));
      expect((name.minLines, name.maxLines), (1, 3));
      expect(name.keyboardType, TextInputType.text);
      expect(find.text('La somme des aliments du repas.'), findsOneWidget);
      expect(find.text('Calculé à partir des aliments.'), findsOneWidget);
      // Les lignes, et la mention de la base, version comprise.
      expect(find.text('Poulet'), findsOneWidget);
      expect(find.text('Blanc de poulet, cuit'), findsNothing);
      expect(find.text('Poulet, filet, sans peau, cuit'), findsOneWidget);
      expect(
        find.text(
          'Source : Anses, Table de composition nutritionnelle des aliments '
          'Ciqual (version 2020-07-07), Licence Ouverte Etalab 2.0, '
          'ciqual.anses.fr.',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('au lecteur d’écran : chaque champ porte son libellé, chaque '
        'titre est seul, chaque aliment se lit sur sa ligne', (tester) async {
      final semantics = tester.ensureSemantics();
      await openMealEditor(
        tester,
        withLunch(),
        AppRoutes.meal('repas-compose'),
      );

      expect(
        tester.getSemantics(fieldLabelled('Nom du repas')),
        isSemantics(
          isTextField: true,
          label: 'Nom du repas',
          value: 'Poulet, riz, brocoli',
        ),
      );
      // Le libellé et sa grille, d'un seul groupe.
      final moments = tester.getSemantics(find.text('Moment de la journée'));
      expect(moments.label, 'Moment de la journée');
      expect(moments.childrenCount, MealMoment.values.length);
      for (final title in [
        'QUANTITÉ',
        'VALEURS NUTRITIONNELLES',
        'ALIMENTS COMPOSANT LE REPAS',
      ]) {
        expect(
          tester.getSemantics(find.text(title)),
          isSemantics(label: title, isHeader: true),
        );
      }
      expect(
        tester.getSemantics(fieldLabelled('Quantité (grammes)')),
        isSemantics(
          isTextField: true,
          isHeader: false,
          label: 'Quantité (grammes)',
          value: '320',
        ),
      );
      expect(
        tester.getSemantics(find.text('Poulet, filet, sans peau, cuit')),
        isSemantics(label: 'Poulet\nPoulet, filet, sans peau, cuit'),
      );
      semantics.dispose();
    });

    testWidgets('retirer un aliment, corriger une quantité : l’aperçu suit, '
        'les lignes partent sans total', (tester) async {
      final nutrition = withLunch();
      await openMealEditor(tester, nutrition, AppRoutes.meal('repas-compose'));

      await showOnScreen(tester, find.byTooltip('Retirer Brocoli'));
      await tester.tap(find.byTooltip('Retirer Brocoli'));
      await tester.pumpAndSettle();
      expect(find.text('Brocoli'), findsNothing);
      // 180 + 195 : l'aperçu, sans attendre le serveur.
      expect(find.text('375'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(fieldLabelled('Quantité (grammes)'))
            .controller!
            .text,
        '270',
      );

      await tester.pumpAndSettle();
      await showOnScreen(tester, find.text('150 g'));
      await tester.tap(find.text('150 g'));
      await tester.pumpAndSettle();
      expect(find.byType(AppPopupCard), findsOneWidget);
      expect(find.text('Quantité de Riz'), findsWidgets);
      await tester.enterText(
        find.descendant(
          of: find.byType(AppPopupCard),
          matching: find.byType(TextField),
        ),
        '200',
      );
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      // 180 + 260.
      expect(find.text('440'), findsOneWidget);

      await tapText(tester, 'Enregistrer la modification');

      final sent = nutrition.writes.single.write.content;
      expect(sent, isA<ComposedMealContent>());
      final lines = (sent as ComposedMealContent).components;
      // Les lignes GARDÉES partent sous leur identifiant d'origine : le
      // serveur garde leur instantané.
      expect(lines.map((l) => l.id), [
        '11111111-1111-4111-8111-111111111111',
        '22222222-2222-4222-8222-222222222222',
      ]);
      expect(lines.map((l) => l.quantityG), [120, 200]);
      expect(nutrition.meals.single.kcal, 440);
      expect(find.byType(MealEditorScreen), findsNothing);
    });

    testWidgets('retirer le DERNIER aliment : saisie à la main, derniers '
        'totaux gardés', (tester) async {
      final nutrition = withLunch();
      await openMealEditor(tester, nutrition, AppRoutes.meal('repas-compose'));

      for (final name in ['Brocoli', 'Riz', 'Poulet']) {
        await showOnScreen(tester, find.byTooltip('Retirer $name'));
        await tester.tap(find.byTooltip('Retirer $name'));
        await tester.pumpAndSettle();
      }

      // Les tuiles redeviennent des cases, remplies de ce qu'elles
      // affichaient : le poulet seul.
      String tileText(String label) =>
          tester.widget<TextField>(tileField(label)).controller!.text;
      expect(tileText('Calories'), '180');
      expect(tileText('Protéines'), '35');
      expect(tileText('Glucides'), '0');
      expect(tileText('Lipides'), '4');
      final quantity = tester.widget<TextField>(
        fieldLabelled('Quantité (grammes)'),
      );
      expect(quantity.readOnly, isFalse);
      expect(quantity.controller!.text, '120');

      await tester.enterText(tileField('Calories'), '200');
      await tapText(tester, 'Enregistrer la modification');

      final sent = nutrition.writes.single.write.content as ManualMealContent;
      expect(sent.clearsComposition, isTrue);
      expect(sent.kcal, 200);
      expect(sent.proteinG, 35);
      expect(nutrition.meals.single.computed, isFalse);
    });

    testWidgets('renommer seulement : la composition est gardée telle quelle', (
      tester,
    ) async {
      final nutrition = withLunch();
      await openMealEditor(tester, nutrition, AppRoutes.meal('repas-compose'));

      await tester.enterText(fieldLabelled('Nom du repas'), 'Déjeuner');
      await tapText(tester, 'Enregistrer la modification');

      expect(
        nutrition.writes.single.write.content,
        isA<KeptCompositionContent>(),
      );
      expect(nutrition.meals.single.name, 'Déjeuner');
      expect(nutrition.meals.single.kcal, 390);
    });
  });

  testWidgets('un repas ancien sans moment : proposé, puis enregistré', (
    tester,
  ) async {
    final nutrition = FakeNutritionRepository()
      ..meals.add(oldMealWithoutMoment(eatenAt: yesterdayAt(20, 0)));
    await openMealEditor(tester, nutrition, AppRoutes.meal('repas-ancien'));

    // 20 h : le dîner, déduit de l'heure — rien n'est encore écrit.
    expect(selectedMoment(tester).label, 'Dîner');
    expect(nutrition.meals.single.moment, isNull);

    await tapText(tester, 'Enregistrer la modification');

    expect(nutrition.meals.single.moment, MealMoment.dinner);
    // Saisi à la main, il le reste : aucune composition à retirer.
    final sent = nutrition.writes.single.write.content as ManualMealContent;
    expect(sent.clearsComposition, isFalse);
    expect(sent.kcal, 420);
  });

  testWidgets('un repas daté du futur est refusé AVANT l’envoi', (
    tester,
  ) async {
    final nutrition = FakeNutritionRepository();
    await openMealEditor(tester, nutrition, AppRoutes.newMeal());
    await tester.enterText(fieldLabelled('Nom du repas'), 'Pâtes');
    await tester.enterText(tileField('Calories'), '600');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MealEditorScreen)),
    );
    container
        .read(mealEditorProvider((mealId: null, day: null)).notifier)
        .setEatenAt(DateTime.now().add(const Duration(hours: 2)));
    await tester.pumpAndSettle();
    await tapText(tester, 'Ajouter au journal');

    expect(
      find.text('On ne mange pas demain : choisis un moment passé.'),
      findsOneWidget,
    );
    expect(nutrition.writes, isEmpty);
    expect(find.byType(MealEditorScreen), findsOneWidget);
  });
}
