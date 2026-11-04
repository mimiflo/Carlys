import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/barcode.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/domain/services/packaged_meal.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/scanned_product_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_nutrition_repository.dart';

/// Scanner un aliment : le produit d'un code-barres, dosé, entre au journal.
void main() {
  const nutella = PackagedFood(
    barcode: '3017620422003',
    name: 'Pâte à tartiner',
    brand: 'Nutella',
    per100g: FoodPer100g(kcal: 539, proteinG: 6.3, fatG: 30.9),
    servingQuantity: 15,
  );
  const jus = PackagedFood(
    barcode: '5449000000996',
    name: 'Jus d’orange',
    per100g: FoodPer100g(kcal: 43, carbsG: 9.5),
    liquid: true,
  );

  test('le chiffre de contrôle se vérifie sur l’appareil, comme sur l’API', () {
    expect(isProductBarcode('3017620422003'), isTrue);
    expect(isProductBarcode('96385074'), isTrue);
    expect(isProductBarcode('036000291452'), isTrue);
    expect(isProductBarcode('3017620422004'), isFalse);
    expect(isProductBarcode('123456789'), isFalse);
    expect(isProductBarcode('abc'), isFalse);
  });

  group('packagedMeal', () {
    test(
      'la règle de trois sur 100 g, arrondie ; une macro inconnue le reste',
      () {
        final write = packagedMeal(nutella, 15, DateTime(2026, 10, 4, 8));
        final content = write.content as ManualMealContent;
        expect(write.name, 'Pâte à tartiner · Nutella');
        expect(write.moment, MealMoment.breakfast);
        expect(content.kcal, 81);
        expect(content.proteinG, 1);
        expect(content.carbsG, isNull);
        expect(content.fatG, 5);
        expect(content.quantity, 15);
        expect(content.quantityUnit, MealQuantityUnit.gram);
      },
    );

    test('une boisson se compte en millilitres', () {
      final content =
          packagedMeal(jus, 250, DateTime(2026, 10, 4, 16)).content
              as ManualMealContent;
      expect(content.kcal, 108);
      expect(content.quantityUnit, MealQuantityUnit.milliliter);
    });

    test('un nom trop long se borne comme tout nom de repas', () {
      final long = PackagedFood(
        barcode: '1',
        name: 'x' * 118,
        brand: 'Marque',
        per100g: const FoodPer100g(kcal: 100),
      );
      expect(packagedMeal(long, 100, DateTime(2026)).name.length, 120);
    });
  });

  group('la feuille du produit', () {
    Future<FakeNutritionRepository> open(
      WidgetTester tester,
      String code, {
      PackagedFood? product,
      Object? failure,
    }) async {
      final nutrition = FakeNutritionRepository()..productFailure = failure;
      if (product != null) nutrition.products[code] = product;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [nutritionRepositoryProvider.overrideWithValue(nutrition)],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAppSheet<bool>(
                    context,
                    builder: (_) =>
                        ScannedProductSheet(barcode: code, day: DateTime.now()),
                  ),
                  child: const Text('scanner'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('scanner'));
      await tester.pumpAndSettle();
      return nutrition;
    }

    testWidgets(
      'trouvé : une portion proposée, les valeurs suivent la saisie',
      (tester) async {
        final nutrition = await open(tester, nutella.barcode, product: nutella);

        expect(find.text('Pâte à tartiner'), findsOneWidget);
        expect(find.text('Nutella'), findsOneWidget);
        expect(find.textContaining('Open Food Facts'), findsOneWidget);
        // La portion de l'emballage : 15 g, soit 81 kcal.
        expect(find.text('81'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '30');
        await tester.pumpAndSettle();
        expect(find.text('162'), findsOneWidget);

        await tester.tap(find.text('Ajouter au journal'));
        await tester.pumpAndSettle();
        final repas = nutrition.meals.single;
        expect(repas.kcal, 162);
        expect(repas.name, 'Pâte à tartiner · Nutella');
        expect(
          find.text('Pâte à tartiner'),
          findsNothing,
          reason: 'feuille fermée',
        );
      },
    );

    testWidgets('quantité vide ou nulle : le bouton s’éteint', (tester) async {
      await open(tester, nutella.barcode, product: nutella);
      await tester.enterText(find.byType(TextField), '0');
      await tester.pumpAndSettle();
      final bouton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Ajouter au journal'),
      );
      expect(bouton.onPressed, isNull);
    });

    testWidgets(
      'plus de deux décimales : refusé ici plutôt que par le serveur',
      (tester) async {
        await open(tester, nutella.barcode, product: nutella);
        await tester.enterText(find.byType(TextField), '15,555');
        await tester.pumpAndSettle();
        final bouton = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Ajouter au journal'),
        );
        expect(bouton.onPressed, isNull);
        expect(find.textContaining('deux décimales'), findsOneWidget);
      },
    );

    testWidgets('un ajout refusé se rejoue sous le MÊME identifiant', (
      tester,
    ) async {
      final nutrition = await open(tester, nutella.barcode, product: nutella)
        ..writeFailure = const NetworkException('coupé');
      await tester.tap(find.text('Ajouter au journal'));
      await tester.pumpAndSettle();
      expect(nutrition.meals, isEmpty);
      expect(
        find.text('Pâte à tartiner'),
        findsOneWidget,
        reason: 'feuille ouverte',
      );

      await tester.tap(find.text('Ajouter au journal'));
      await tester.pumpAndSettle();
      expect(nutrition.meals, hasLength(1));
      expect(nutrition.writes.map((w) => w.id).toSet(), hasLength(1));
    });

    testWidgets('inconnu : la saisie à la main est proposée', (tester) async {
      await open(tester, '4006381333931');
      expect(find.text('Produit inconnu'), findsOneWidget);
      expect(find.text('Saisir à la main'), findsOneWidget);
    });

    testWidgets('hors ligne : on le dit, et on peut réessayer', (tester) async {
      final nutrition = await open(
        tester,
        nutella.barcode,
        product: nutella,
        failure: const NetworkException('hors ligne'),
      );
      expect(find.textContaining('revient avec le réseau'), findsOneWidget);
      // La base en panne n'empêche pas de manger : la saisie reste offerte.
      expect(find.text('Saisir à la main'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Pâte à tartiner'), findsOneWidget);
      expect(nutrition.productReads, hasLength(2));
    });
  });
}
