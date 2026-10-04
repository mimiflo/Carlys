// Captures de l'onglet Nutrition (maquette d'octobre 2026) — OUTIL :
//   flutter test tool/screenshots/nutrition_test.dart --update-goldens
//
// Comme les autres fichiers de ce dossier, il est HORS de test/ : la CI ne
// compare jamais ces rendus, et les PNG sont ignorés par git. Les photos des
// repas (assets/) sont des images générées pour la capture : la journée
// montrée est plausible, aucune n'est celle d'une personne réelle.
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/data/services/image_picker_meal_photo_picker.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/providers/water_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/fake_auth_repository.dart';
import '../../test/support/fake_meal_photo_picker.dart';
import '../../test/support/fake_nutrition_repository.dart';
import '../../test/support/fake_water_store.dart';
import '../../test/support/fake_workout_repository.dart';
import '../../test/support/first_run_prefs.dart';
import '../../test/support/local_data_overrides.dart';
import '../../test/support/navigation.dart' as navigation;
import '../../test/support/sample_meals.dart';
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

  Widget app(
    FakeNutritionRepository nutrition, {
    FakeMealPhotoPicker? picker,
  }) => ProviderScope(
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
      if (picker != null) mealPhotoPickerProvider.overrideWithValue(picker),
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

  /// Les octets d'une photo se décodent HORS de l'horloge du test : on leur
  /// laisse un vrai instant, puis on repeint.
  Future<void> decodePhotos(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  /// Le scan d'une assiette : la photo du déjeuner, analysée puis rendue
  /// au repas pré-rempli (deux aliments de la base, un qui n'y est pas).
  Future<FakeNutritionRepository> ouvrirLeScan(
    WidgetTester tester,
    List<MealScan> replies,
  ) async {
    telephone(tester);
    final nutrition = journee()
      ..scanReplies.addAll(replies)
      ..foods.addEntries(sampleFoods.map((f) => MapEntry(f.code, f)));
    final photo = File(
      'tool/screenshots/assets/dejeuner.jpg',
    ).readAsBytesSync();
    await tester.pumpWidget(
      app(nutrition, picker: FakeMealPhotoPicker(photo: photo)),
    );
    await tester.pumpAndSettle();
    await navigation.openNutrition(tester);
    await tester.tap(find.text('Scanner un aliment'));
    await tester.pumpAndSettle();
    return nutrition;
  }

  testWidgets('scan d’assiette : la photo, l’analyse, le repas pré-rempli', (
    tester,
  ) async {
    await ouvrirLeScan(tester, const [
      MealScan(id: 's', status: MealScanStatus.pending),
      MealScan(
        id: 's',
        status: MealScanStatus.done,
        items: [
          MealScanItem(seen: 'Poulet grillé', grams: 150, food: pouletCuit),
          MealScanItem(seen: 'Riz blanc', grams: 120, food: rizBlancCuit),
          MealScanItem(seen: 'Brocoli', grams: 100, food: brocoliCuit),
        ],
      ),
    ]);
    await capture(tester, 'nutrition-05-scan');

    await tester.ensureVisible(find.text('Choisir une photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir une photo'));
    await tester.pump();
    await decodePhotos(tester);
    await capture(tester, 'nutrition-06-scan-analyse');

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    // Le message « Repas reconnu » passé, l'écran du repas tel qu'on le relit.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await decodePhotos(tester);
    await capture(tester, 'nutrition-07-scan-repas');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await capture(tester, 'nutrition-08-scan-aliments');
    await purge(tester);
  });

  testWidgets('scan d’assiette : rien de la base reconnu', (tester) async {
    await ouvrirLeScan(tester, const [
      MealScan(
        id: 's',
        status: MealScanStatus.done,
        items: [MealScanItem(seen: 'Bobun', grams: 300)],
      ),
    ]);
    await tester.ensureVisible(find.text('Choisir une photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir une photo'));
    await tester.pumpAndSettle();
    await decodePhotos(tester);
    await capture(tester, 'nutrition-09-scan-echec');
    await purge(tester);
  });
}
