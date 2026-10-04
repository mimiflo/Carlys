// Captures de l'onglet Nutrition (maquette d'octobre 2026) — OUTIL :
//   flutter test tool/screenshots/nutrition_test.dart --update-goldens
//
// Comme les autres fichiers de ce dossier, il est HORS de test/ : la CI ne
// compare jamais ces rendus, et les PNG sont ignorés par git. Les photos des
// repas (assets/) sont des images générées pour la capture : la journée
// montrée est plausible, aucune n'est celle d'une personne réelle.
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:io';

import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/providers/water_providers.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/scanned_product_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/fake_auth_repository.dart';
import '../../test/support/fake_nutrition_repository.dart';
import '../../test/support/fake_water_store.dart';
import '../../test/support/fake_workout_repository.dart';
import '../../test/support/first_run_prefs.dart';
import '../../test/support/local_data_overrides.dart';
import '../../test/support/navigation.dart' as navigation;
import 'capture_test.dart' show loadRealFonts;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRealFonts);

  setUp(() {
    seedCompletedFirstRun();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  void telephone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  /// Une journée plausible : quatre repas, trois avec leur photo.
  FakeNutritionRepository journee() {
    final now = DateTime.now();
    DateTime at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    MealEntry repas(
      String id,
      MealMoment moment,
      DateTime when,
      String name,
      int kcal,
      int p,
      int c,
      int f, {
      bool photo = true,
    }) => MealEntry(
      id: id,
      name: name,
      kcal: kcal,
      moment: moment,
      eatenAt: when.toUtc(),
      proteinG: p,
      carbsG: c,
      fatG: f,
      photoUpdatedAt: photo ? when.toUtc() : null,
    );
    final nutrition =
        FakeNutritionRepository(
            weightKg: 80,
            sex: BiologicalSex.male,
            birthDate: DateTime.utc(1996, 3, 12),
            heightCm: 180,
            activityLevel: ActivityLevel.moderate,
            goal: NutritionGoal.maintain,
          )
          ..meals.addAll([
            repas(
              'petit-dejeuner',
              MealMoment.breakfast,
              at(7, 30),
              'Skyr, granola, myrtilles',
              482,
              28,
              62,
              12,
            ),
            repas(
              'dejeuner',
              MealMoment.lunch,
              at(12, 15),
              'Poulet, riz, brocoli',
              612,
              46,
              68,
              18,
            ),
            repas(
              'collation',
              MealMoment.snack,
              at(16, 20),
              'Banane, beurre de cacahuète',
              180,
              6,
              24,
              8,
            ),
            repas(
              'diner',
              MealMoment.dinner,
              at(19, 40),
              'Saumon, patate douce, légumes',
              274,
              32,
              28,
              10,
            ),
          ]);
    for (final id in ['petit-dejeuner', 'dejeuner', 'collation', 'diner']) {
      nutrition.photos[id] = File(
        'tool/screenshots/assets/$id.jpg',
      ).readAsBytesSync();
    }
    return nutrition;
  }

  Widget app(FakeNutritionRepository nutrition) => ProviderScope(
    overrides: [
      appEnvironmentProvider.overrideWithValue(
        const AppEnvironment(
          flavor: AppFlavor.development,
          apiBaseUrl: 'http://localhost:3000',
        ),
      ),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(storedSession: true),
      ),
      ...localDataOverrides(),
      syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
      appRestoreProvider.overrideWithValue(NoopAppRestore()),
      nutritionRepositoryProvider.overrideWithValue(nutrition),
      waterStoreProvider.overrideWithValue(FakeWaterStore(milliliters: 1250)),
    ],
    child: const CarlysApp(),
  );

  Future<void> purge(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('onglet Nutrition : la journée, du haut au bas', (tester) async {
    telephone(tester);
    await tester.pumpWidget(app(journee()));
    await tester.pumpAndSettle();
    await navigation.openNutrition(tester);
    // Les photos se lisent (cache, puis dépôt) : on les laisse arriver.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'nutrition-01-journee');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await capture(tester, 'nutrition-02-journal');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes besoins'));
    await tester.pumpAndSettle();
    await capture(tester, 'nutrition-03-metabolisme');
    await purge(tester);
  });

  testWidgets('scanner un aliment : la feuille du produit, et la caméra', (
    tester,
  ) async {
    telephone(tester);
    final nutrition = journee();
    nutrition.products['3017620422003'] = const PackagedFood(
      barcode: '3017620422003',
      name: 'Pâte à tartiner aux noisettes',
      brand: 'Nutella',
      per100g: FoodPer100g(kcal: 539, proteinG: 6.3, carbsG: 57.5, fatG: 30.9),
      servingQuantity: 15,
    );
    await tester.pumpWidget(app(nutrition));
    await tester.pumpAndSettle();
    await navigation.openNutrition(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    unawaited(
      showAppSheet<bool>(
        tester.element(find.byType(NutritionScreen)),
        builder: (_) =>
            ScannedProductSheet(barcode: '3017620422003', day: DateTime.now()),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'nutrition-05-produit-scanne');

    Navigator.of(tester.element(find.byType(ScannedProductSheet))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scanner un aliment'));
    await tester.pumpAndSettle();
    await capture(tester, 'nutrition-06-scanner');
    await purge(tester);
  });

  testWidgets('onglet Nutrition : profil incomplet, journal vide', (
    tester,
  ) async {
    telephone(tester);
    await tester.pumpWidget(app(FakeNutritionRepository()));
    await tester.pumpAndSettle();
    await navigation.openNutrition(tester);
    await capture(tester, 'nutrition-04-premier-jour');
    await purge(tester);
  });
}
