import 'dart:async';

import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/controllers/meal_editor_controller.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/meal_editor_screen.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/meal_journal_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_nutrition_repository.dart';
import '../../support/meal_editor_app.dart';
import '../../support/sample_meals.dart';

/// PENDANT L'ENVOI : l'aller-retour réseau d'un enregistrement ou d'une
/// suppression peut durer (jusqu'à 10 s de connexion et 20 s de réception).
///
/// Ce que ces tests protègent : rien de ce qu'on fait pendant ce temps ne
/// se perd en silence, un retour ne dépile pas la page du dessous, et une
/// réponse perdue ne fait pas enregistrer l'ANCIEN repas à la place du
/// corrigé.
void main() {
  DateTime yesterdayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - 1, hour, minute);
  }

  FakeNutritionRepository withLunch() => FakeNutritionRepository()
    ..foods.addEntries(sampleFoods.map((f) => MapEntry(f.code, f)))
    ..meals.add(composedLunch(eatenAt: yesterdayAt(12, 30)));

  /// Touche [text] SANS attendre que tout se pose : le bouton qui envoie
  /// tourne tant que l'écriture est retenue.
  Future<void> tapWhileSending(WidgetTester tester, String text) async {
    await tester.pumpAndSettle();
    await showOnScreen(tester, find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  MealEditorController editorOf(WidgetTester tester, MealEditorKey key) =>
      ProviderScope.containerOf(
        tester.element(find.byType(MealEditorScreen)),
      ).read(mealEditorProvider(key).notifier);

  group('un retour pendant l’envoi', () {
    testWidgets('est retenu ; l’écran se referme ensuite une seule fois', (
      tester,
    ) async {
      final held = Completer<void>();
      final nutrition = withLunch()..writeHold = held;
      await openMealEditor(tester, nutrition, AppRoutes.meal('repas-compose'));
      await tester.enterText(fieldLabelled('Nom du repas'), 'Déjeuner');
      await tapWhileSending(tester, 'Enregistrer la modification');

      // Le retour système, pendant l'envoi : l'écran tient.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(MealEditorScreen), findsOneWidget);

      held.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MealEditorScreen), findsNothing);
      // La page d'avant est TOUJOURS là : rien d'autre n'a été dépilé.
      expect(find.byType(MealJournalSection), findsOneWidget);
      expect(find.text('Repas modifié.'), findsOneWidget);
      expect(nutrition.meals.single.name, 'Déjeuner');
    });

    testWidgets('l’écran refermé ailleurs : l’enregistrement ne dépile rien '
        'de plus', (tester) async {
      final held = Completer<void>();
      final nutrition = withLunch()..writeHold = held;
      final router = await pumpMealApp(tester, nutrition);
      unawaited(router.push(AppRoutes.meal('repas-compose')));
      await tester.pumpAndSettle();
      await tapWhileSending(tester, 'Enregistrer la modification');

      // Une navigation venue d'ailleurs (une notification, par exemple).
      router.go(mealHomeRoute);
      await tester.pumpAndSettle();
      held.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MealJournalSection), findsOneWidget);
      expect(find.text('Repas modifié.'), findsOneWidget);
    });

    testWidgets('pareil pour une suppression', (tester) async {
      final held = Completer<void>();
      final nutrition = withLunch()..writeHold = held;
      final router = await pumpMealApp(tester, nutrition);
      unawaited(router.push(AppRoutes.meal('repas-compose')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Supprimer ce repas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(MealEditorScreen), findsOneWidget);

      router.go(mealHomeRoute);
      await tester.pumpAndSettle();
      held.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MealJournalSection), findsOneWidget);
      expect(find.text('Repas supprimé.'), findsOneWidget);
      expect(nutrition.meals, isEmpty);
    });
  });

  group('la saisie, pendant l’envoi', () {
    testWidgets('est gelée : ce qui part est ce qui reste à l’écran', (
      tester,
    ) async {
      final held = Completer<void>();
      final nutrition = withLunch()..writeHold = held;
      const key = (mealId: 'repas-compose', day: null);
      await openMealEditor(tester, nutrition, AppRoutes.meal('repas-compose'));
      await tester.enterText(fieldLabelled('Nom du repas'), 'Déjeuner');
      final nameField = tester.state<EditableTextState>(
        find.descendant(
          of: fieldLabelled('Nom du repas'),
          matching: find.byType(EditableText),
        ),
      );
      expect(nameField.widget.focusNode.hasFocus, isTrue);

      await tapWhileSending(tester, 'Enregistrer la modification');

      // Le clavier se ferme : plus rien ne s'écrit dans le nom.
      expect(nameField.widget.focusNode.hasFocus, isFalse);
      // La croix d'un aliment ne répond plus au doigt…
      await tester.tap(find.byTooltip('Retirer Brocoli'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('Brocoli'), findsOneWidget);
      // … ni le contrôleur, par quelque chemin que ce soit.
      final editor = editorOf(tester, key);
      editor
        ..setName('Nom corrigé')
        ..removeLine('33333333-3333-4333-8333-333333333333')
        ..chooseMoment(MealMoment.dinner);
      await tester.pump();
      expect(find.text('Nom corrigé'), findsNothing);
      expect(find.text('Brocoli'), findsOneWidget);

      held.complete();
      await tester.pumpAndSettle();

      final saved = nutrition.meals.single;
      expect(saved.name, 'Déjeuner');
      expect(saved.components, hasLength(3));
      expect(saved.moment, MealMoment.lunch);
      expect(find.text('Repas modifié.'), findsOneWidget);
    });

    testWidgets('un échec rend la main, sur ce qui était à l’écran', (
      tester,
    ) async {
      final held = Completer<void>();
      final nutrition = FakeNutritionRepository()
        ..meals.add(manualBreakfast(eatenAt: yesterdayAt(8, 0)))
        ..writeHold = held
        ..writeFailure = const NetworkException('Serveur injoignable');
      await openMealEditor(tester, nutrition, AppRoutes.meal('repas-saisi'));
      await tester.enterText(tileField('Calories'), '400');
      await tapWhileSending(tester, 'Enregistrer la modification');

      held.complete();
      await tester.pumpAndSettle();

      expect(find.byType(MealEditorScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(tileField('Calories')).controller!.text,
        '400',
      );
      // Et la saisie reprend.
      await tester.enterText(tileField('Calories'), '410');
      nutrition.writeHold = null;
      await tapWhileSending(tester, 'Enregistrer la modification');
      await tester.pumpAndSettle();
      expect(nutrition.meals.single.kcal, 410);
    });
  });

  group('une création dont la réponse s’est perdue', () {
    testWidgets('corrigée puis renvoyée : c’est la CORRECTION qui compte', (
      tester,
    ) async {
      final nutrition = FakeNutritionRepository()
        ..lostResponse = const NetworkException('Délai dépassé');
      await openMealEditor(tester, nutrition, AppRoutes.newMeal());
      await tester.enterText(fieldLabelled('Nom du repas'), 'Pomme');
      await tester.enterText(tileField('Calories'), '80');
      await tapWhileSending(tester, 'Ajouter au journal');
      await tester.pumpAndSettle();

      // Le serveur a écrit, mais l'écran ne l'a pas su.
      expect(find.byType(MealEditorScreen), findsOneWidget);
      expect(nutrition.meals.single.kcal, 80);

      await tester.enterText(tileField('Calories'), '95');
      await tapWhileSending(tester, 'Ajouter au journal');
      await tester.pumpAndSettle();

      expect(find.byType(MealEditorScreen), findsNothing);
      expect(nutrition.meals, hasLength(1));
      expect(nutrition.meals.single.kcal, 95);
      // Relu d'abord, sous le MÊME identifiant, puis corrigé.
      expect(nutrition.mealReads, [nutrition.meals.single.id]);
      expect(nutrition.writes.map((w) => w.id).toSet(), hasLength(1));
    });

    testWidgets('composée, puis passée à la main : la composition part', (
      tester,
    ) async {
      final nutrition = FakeNutritionRepository()
        ..foods.addEntries(sampleFoods.map((f) => MapEntry(f.code, f)))
        ..lostResponse = const NetworkException('Délai dépassé');
      const key = (mealId: null, day: null);
      await openMealEditor(tester, nutrition, AppRoutes.newMeal());
      await tester.enterText(fieldLabelled('Nom du repas'), 'Poulet');
      editorOf(tester, key).addFood(pouletCuit, 120, sampleSource);
      await tapWhileSending(tester, 'Ajouter au journal');
      await tester.pumpAndSettle();
      expect(nutrition.meals.single.computed, isTrue);

      final line = nutrition.meals.single.components.single;
      editorOf(tester, key).removeLine(line.id);
      await tester.pumpAndSettle();
      await tester.enterText(tileField('Calories'), '200');
      await tapWhileSending(tester, 'Ajouter au journal');
      await tester.pumpAndSettle();

      expect(find.byType(MealEditorScreen), findsNothing);
      final saved = nutrition.meals.single;
      expect(saved.computed, isFalse);
      expect(saved.kcal, 200);
    });

    testWidgets('jamais écrite : relue absente, elle se crée', (tester) async {
      final nutrition = FakeNutritionRepository()
        ..writeFailure = const NetworkException('Serveur injoignable');
      await openMealEditor(tester, nutrition, AppRoutes.newMeal());
      await tester.enterText(fieldLabelled('Nom du repas'), 'Pomme');
      await tester.enterText(tileField('Calories'), '80');
      await tapWhileSending(tester, 'Ajouter au journal');
      await tester.pumpAndSettle();
      expect(nutrition.meals, isEmpty);

      await tapWhileSending(tester, 'Ajouter au journal');
      await tester.pumpAndSettle();

      expect(nutrition.meals.single.kcal, 80);
      expect(find.byType(MealEditorScreen), findsNothing);
    });

    testWidgets('une création qui aboutit du premier coup ne relit rien', (
      tester,
    ) async {
      final nutrition = FakeNutritionRepository();
      await openMealEditor(tester, nutrition, AppRoutes.newMeal());
      await tester.enterText(fieldLabelled('Nom du repas'), 'Pomme');
      await tester.enterText(tileField('Calories'), '80');
      await tapWhileSending(tester, 'Ajouter au journal');
      await tester.pumpAndSettle();

      expect(nutrition.meals.single.kcal, 80);
      expect(nutrition.mealReads, isEmpty);
    });
  });

  testWidgets('la corbeille de l’en-tête se dit désactivée pendant l’envoi', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final held = Completer<void>();
    await openMealEditor(
      tester,
      withLunch()..writeHold = held,
      AppRoutes.meal('repas-compose'),
    );
    final trash = find.descendant(
      of: find.byType(AppRoundIconButton),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(trash).onPressed, isNotNull);

    await tapWhileSending(tester, 'Enregistrer la modification');

    expect(tester.widget<IconButton>(trash).onPressed, isNull);
    expect(
      tester.getSemantics(find.byTooltip('Supprimer ce repas')),
      isSemantics(
        tooltip: 'Supprimer ce repas',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    held.complete();
    await tester.pumpAndSettle();
    semantics.dispose();
  });
}
