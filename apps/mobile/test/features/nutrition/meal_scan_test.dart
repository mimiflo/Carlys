import 'dart:typed_data';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;

import '../../support/fake_meal_photo_picker.dart';
import '../../support/fake_nutrition_repository.dart';
import '../../support/meal_editor_app.dart';
import '../../support/sample_meals.dart';

/// LE SCAN D'ASSIETTE, vu de l'écran : la tuile du journal, la photo,
/// l'analyse en fond (relue jusqu'à son résultat), puis l'écran du repas
/// PRÉ-REMPLI que la personne vérifie. Rien ne s'écrit sans elle.
void main() {
  final photo = img.encodeJpg(
    img.Image(width: 8, height: 8)..clear(img.ColorRgb8(120, 60, 200)),
  );

  const lunch = [
    MealScanItem(seen: 'Poulet grillé', grams: 150, food: pouletCuit),
    MealScanItem(seen: 'Riz blanc', grams: 120, food: rizBlancCuit),
    MealScanItem(seen: 'Sauce maison', grams: 30),
  ];

  MealScan scan(MealScanStatus status, {List<MealScanItem>? items}) =>
      MealScan(id: 'x', status: status, items: items ?? const []);

  Future<GoRouter> startScan(
    WidgetTester tester,
    FakeNutritionRepository nutrition, {
    Uint8List? picked,
  }) async {
    final router = await pumpMealApp(
      tester,
      nutrition,
      picker: FakeMealPhotoPicker(photo: picked ?? photo),
    );
    await tester.tap(find.text('Scanner un aliment'));
    await tester.pumpAndSettle();
    expect(find.text('Scanner mon assiette'), findsOneWidget);
    await tester.tap(find.text('Choisir une photo'));
    await tester.pump();
    return router;
  }

  testWidgets('la photo analysée ouvre le repas pré-rempli, à vérifier', (
    tester,
  ) async {
    final nutrition = FakeNutritionRepository()
      ..scanReplies.addAll([
        scan(MealScanStatus.pending),
        scan(MealScanStatus.done, items: lunch),
      ]);
    await startScan(tester, nutrition);

    // En cours : la photo et l'attente, dites.
    expect(find.textContaining('une à deux minutes'), findsOneWidget);
    expect(nutrition.scannedPhotos.values.single, photo);

    // La relecture suivante rend le résultat : l'écran du repas s'ouvre.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter au journal'), findsOneWidget);
    expect(find.text('Scanner mon assiette'), findsNothing);
    expect(find.textContaining('Pas dans la base : Sauce maison'), findsOne);

    // Les deux aliments reconnus, leurs grammes, le nom tiré d'eux ; la
    // photo jointe. RIEN d'écrit encore.
    expect(find.text('Poulet, Riz'), findsOneWidget);
    expect(find.textContaining('Poulet, filet'), findsOneWidget);
    expect(find.textContaining('Riz blanc, cuit'), findsOneWidget);
    final thumbnail = tester.widget<AppThumbnail>(find.byType(AppThumbnail));
    expect((thumbnail.image! as MemoryImage).bytes, photo);
    expect(nutrition.writes, isEmpty);

    await showOnScreen(tester, find.text('Ajouter au journal'));
    await tester.tap(find.text('Ajouter au journal'));
    await tester.pumpAndSettle();
    final content = nutrition.writes.single.write.content;
    expect(content, isA<ComposedMealContent>());
    expect(
      [
        for (final c in (content as ComposedMealContent).components)
          (c.foodCode, c.quantityG),
      ],
      [(990001, 150.0), (990002, 120.0)],
    );
  });

  testWidgets('un repas ouvert ensuite repart vide : le scan est consommé', (
    tester,
  ) async {
    final nutrition = FakeNutritionRepository()
      ..scanReplies.add(scan(MealScanStatus.done, items: lunch));
    final router = await startScan(tester, nutrition);
    await tester.pumpAndSettle();
    expect(find.text('Poulet, Riz'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter un repas').first);
    await tester.pumpAndSettle();
    expect(find.text('Poulet, Riz'), findsNothing);
    expect(find.byType(AppThumbnail), findsOneWidget);
    final thumbnail = tester.widget<AppThumbnail>(find.byType(AppThumbnail));
    expect(thumbnail.image, isNull);
  });

  testWidgets('rien de la base reconnu : l’échec le dit, sans repas', (
    tester,
  ) async {
    final nutrition = FakeNutritionRepository()
      ..scanReplies.add(
        scan(
          MealScanStatus.done,
          items: const [MealScanItem(seen: 'Bobun', grams: 300)],
        ),
      );
    await startScan(tester, nutrition);
    await tester.pumpAndSettle();
    expect(find.textContaining('(Bobun)'), findsOneWidget);
    expect(find.text('Reprendre une photo'), findsOneWidget);
    expect(find.text('Saisir à la main'), findsOneWidget);
    expect(find.text('Ajouter au journal'), findsNothing);

    // Réessayer revient au choix de la photo.
    await showOnScreen(tester, find.text('Reprendre une photo'));
    await tester.tap(find.text('Reprendre une photo'));
    await tester.pumpAndSettle();
    expect(find.text('Prendre la photo'), findsOneWidget);
  });

  testWidgets('l’échec du serveur s’affiche tel qu’il l’écrit', (tester) async {
    final nutrition = FakeNutritionRepository()
      ..scanReplies.add(
        const MealScan(
          id: 'x',
          status: MealScanStatus.failed,
          error: 'Le coach est très sollicité.',
        ),
      );
    await startScan(tester, nutrition);
    await tester.pumpAndSettle();
    expect(find.text('Le coach est très sollicité.'), findsOneWidget);
  });

  testWidgets('sans abonnement, le refus est expliqué', (tester) async {
    final nutrition = FakeNutritionRepository()
      ..scanFailure = const ForbiddenException('forbidden', statusCode: 403);
    await startScan(tester, nutrition);
    await tester.pumpAndSettle();
    expect(find.textContaining('réservé aux abonnés'), findsOneWidget);
  });

  testWidgets('hors ligne, le scan dit pourquoi', (tester) async {
    final nutrition = FakeNutritionRepository()
      ..scanFailure = const NetworkException('offline');
    await startScan(tester, nutrition);
    await tester.pumpAndSettle();
    expect(find.textContaining('Hors ligne'), findsOneWidget);
  });

  testWidgets('quitter pendant l’analyse : la relecture s’arrête, sans repas', (
    tester,
  ) async {
    final nutrition = FakeNutritionRepository()
      ..scanReplies.addAll([
        scan(MealScanStatus.pending),
        scan(MealScanStatus.done, items: lunch),
      ]);
    final router = await startScan(tester, nutrition);
    expect(find.textContaining('une à deux minutes'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter au journal'), findsNothing);
    expect(find.text('Scanner un aliment'), findsOneWidget);
    expect(nutrition.writes, isEmpty);
  });

  testWidgets('une erreur inattendue : l’échec se dit, jamais d’attente '
      'sans fin', (tester) async {
    final nutrition = FakeNutritionRepository()
      ..scanFailure = StateError('réponse illisible');
    await startScan(tester, nutrition);
    await tester.pumpAndSettle();
    expect(find.textContaining('n’a pas abouti'), findsOneWidget);
    expect(find.text('Reprendre une photo'), findsOneWidget);
  });
}
