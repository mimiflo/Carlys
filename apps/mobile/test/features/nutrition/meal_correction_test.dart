import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/meal_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_nutrition_repository.dart';
import '../../support/meal_editor_app.dart';

/// CE QUE CE FICHIER PROTÈGE : un repas mal saisi se répare, et une journée
/// oubliée se rattrape.
///
/// Le serveur servait l'historique depuis toujours — `GET /nutrition/meals`
/// prend deux bornes — mais l'application ne demandait QUE la journée en
/// cours, et n'offrait que « retirer ». Corriger une calorie voulait donc
/// dire supprimer puis ressaisir : le repas quittait le total, puis revenait
/// sous un AUTRE identifiant. Et un repas oublié la veille était hors de
/// portée, même pour la suppression.
void main() {
  DateTime midi(DateTime jour) =>
      DateTime(jour.year, jour.month, jour.day, 12).toUtc();

  /// Un instant du jour COURANT et déjà PASSÉ.
  ///
  /// Midi, sauf quand il n'est pas encore midi. L'écran refuse un repas
  /// daté du futur — à raison, le serveur aussi — donc un repas d'exemple
  /// posé à « midi aujourd'hui » rendait ces tests rouges entre minuit et
  /// midi, heure locale. Invisible sous UTC, visible sous la
  /// `TZ=Europe/Paris` que la CI impose : en soirée UTC, il est déjà demain
  /// à Paris, et midi n'y est pas encore passé.
  DateTime dejaPris() {
    final now = DateTime.now();
    final midiLocal = DateTime(now.year, now.month, now.day, 12);
    return (midiLocal.isAfter(now) ? now : midiLocal).toUtc();
  }

  MealEntry repas({
    String id = 'repas-1',
    String name = 'Poulet riz',
    int kcal = 650,
    double? quantity,
    MealQuantityUnit? quantityUnit,
    int? proteinG = 45,
    DateTime? eatenAt,
  }) => MealEntry(
    id: id,
    name: name,
    kcal: kcal,
    quantity: quantity,
    quantityUnit: quantityUnit,
    proteinG: proteinG,
    eatenAt: eatenAt ?? dejaPris(),
  );

  /// Toucher le repas du journal ouvre l'écran de correction, plein écran.
  Future<void> ouvrirLaCorrection(WidgetTester tester) async {
    await tester.tap(find.text('Poulet riz'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier ce repas'), findsOneWidget);
  }

  Future<void> enregistrer(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await showOnScreen(tester, find.text('Enregistrer la modification'));
    await tester.tap(find.text('Enregistrer la modification'));
    await tester.pumpAndSettle();
  }

  String caseDe(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;

  testWidgets('la correction s’ouvre PRÉ-REMPLIE', (tester) async {
    final nutrition = FakeNutritionRepository()
      ..meals.add(repas(quantity: 250, quantityUnit: MealQuantityUnit.gram));
    await pumpMealApp(tester, nutrition);

    await ouvrirLaCorrection(tester);

    // Un formulaire vide obligerait à tout ressaisir pour changer un
    // chiffre, et la moindre distraction effacerait les macros.
    expect(caseDe(tester, fieldLabelled('Nom du repas')), 'Poulet riz');
    expect(caseDe(tester, tileField('Calories')), '650');
    expect(caseDe(tester, tileField('Protéines')), '45');
    expect(caseDe(tester, fieldLabelled('Quantité (grammes)')), '250');
  });

  testWidgets('corriger garde l’identifiant : ni suppression ni doublon', (
    tester,
  ) async {
    final nutrition = FakeNutritionRepository()..meals.add(repas());
    await pumpMealApp(tester, nutrition);
    await ouvrirLaCorrection(tester);

    await tester.enterText(tileField('Calories'), '700');
    await enregistrer(tester);

    // UNE entrée, la même, avec la nouvelle valeur : supprimer puis recréer
    // aurait changé l'identifiant et fait disparaître le repas du total
    // entre les deux gestes.
    expect(nutrition.meals, hasLength(1));
    expect(nutrition.meals.single.id, 'repas-1');
    expect(nutrition.meals.single.kcal, 700);
  });

  testWidgets('vider une macro l’EFFACE, au lieu de la conserver', (
    tester,
  ) async {
    final nutrition = FakeNutritionRepository()..meals.add(repas());
    await pumpMealApp(tester, nutrition);
    await ouvrirLaCorrection(tester);

    await tester.enterText(tileField('Protéines'), '');
    await enregistrer(tester);

    // L'écran montrait l'entrée ENTIÈRE : une case vidée veut dire « on ne
    // sait plus », et n'envoyer que les cases remplies laisserait cet
    // effacement sans effet.
    expect(nutrition.meals.single.proteinG, isNull);
  });

  testWidgets('la quantité s’écrit en clair et ne multiplie rien', (
    tester,
  ) async {
    final nutrition = FakeNutritionRepository()
      ..meals.add(
        repas(quantity: 2, quantityUnit: MealQuantityUnit.piece, kcal: 180),
      );
    await pumpMealApp(tester, nutrition);

    // « 2 pièces » à côté de « 180 kcal » : les calories restent celles du
    // repas entier, la quantité les DÉCRIT sans les multiplier.
    expect(find.textContaining('2 pièces'), findsOneWidget);
    expect(find.textContaining('180 kcal'), findsOneWidget);
    // L'en-tête compte 180, pas 360 : on compare à CE que le formateur du
    // dépôt produit, pas à l'espace qu'on croit qu'il met.
    expect(
      find.text('180 / ${formatThousands(2000)} KCAL'.toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('le journal recule d’un jour, et jamais vers demain', (
    tester,
  ) async {
    final hier = DateTime.now().subtract(const Duration(days: 1));
    final nutrition = FakeNutritionRepository()
      ..meals.add(repas(name: 'Omelette d’hier', eatenAt: midi(hier)));
    await pumpMealApp(tester, nutrition);

    // `byTooltip` désigne le Tooltip, pas le bouton : c'est l'icône qui
    // ramène l'IconButton dont on veut lire l'état.
    VoidCallback? demain() => tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
        )
        .onPressed;

    // Aujourd'hui : rien, et la flèche « demain » est ÉTEINTE — un jour à
    // venir n'a rien à montrer ni à recevoir.
    expect(find.textContaining('Rien au journal'), findsOneWidget);
    expect(demain(), isNull);

    await tester.tap(find.byTooltip('Jour précédent'));
    await tester.pumpAndSettle();

    expect(find.text('Hier'), findsOneWidget);
    expect(find.text('Omelette d’hier'), findsOneWidget);
    // Et de là, on peut revenir : la flèche « demain » s'allume.
    expect(demain(), isNotNull);
  });

  group('une quantité se dit avec son unité', () {
    test('les grammes et millilitres ne s’accordent pas', () {
      expect(MealQuantityUnit.gram.spell(250), '250 g');
      expect(MealQuantityUnit.milliliter.spell(330), '330 ml');
    });

    test('les portions et pièces s’accordent au-delà de un', () {
      expect(MealQuantityUnit.portion.spell(1), '1 portion');
      expect(MealQuantityUnit.portion.spell(2), '2 portions');
      expect(MealQuantityUnit.piece.spell(3), '3 pièces');
    });

    test('une demi-portion garde la virgule française, et le singulier', () {
      expect(MealQuantityUnit.portion.spell(1.5), '1,5 portion');
    });

    test('la paire incomplète ne s’écrit PAS à moitié', () {
      // Un serveur d'une version future peut servir une unité que cette
      // application ignore : écrire le nombre tout seul serait pire que se
      // taire.
      expect(
        MealEntry(
          id: 'x',
          name: 'Inconnu',
          kcal: 100,
          quantity: 250,
          eatenAt: DateTime.utc(2026, 9, 19),
        ).spelledQuantity,
        isNull,
      );
    });
  });
}
