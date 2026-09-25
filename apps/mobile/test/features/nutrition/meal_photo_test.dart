import 'dart:async';
import 'dart:typed_data';

import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/meal_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../support/fake_meal_photo_picker.dart';
import '../../support/fake_nutrition_repository.dart';
import '../../support/meal_editor_app.dart';
import '../../support/sample_meals.dart';

/// LA PHOTO DU PLAT, vue de l'écran : la feuille d'options, la prise (par un
/// faux appareil photo : aucun greffon), l'envoi APRÈS l'écriture du repas,
/// le retrait, l'affichage des octets du serveur, et chaque échec DIT.
///
/// Ce que ces tests protègent, d'abord : une photo qui ne part pas ne fait
/// perdre ni le repas ni la photo, et l'écran le dit.
void main() {
  DateTime yesterdayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - 1, hour, minute);
  }

  /// Un vrai JPEG, minuscule : ce que le port rend est « déjà préparé ».
  Uint8List jpeg(int shade) => img.encodeJpg(
    img.Image(width: 8, height: 8)..clear(img.ColorRgb8(shade, shade, 0)),
  );

  FakeNutritionRepository withLunch({Uint8List? photo}) {
    final lunch = composedLunch(eatenAt: yesterdayAt(12, 30));
    final nutrition = FakeNutritionRepository()
      ..foods.addEntries(sampleFoods.map((f) => MapEntry(f.code, f)))
      ..meals.add(lunch);
    if (photo != null) {
      nutrition.photos[lunch.id] = photo;
    }
    return nutrition;
  }

  AppThumbnail thumbnail(WidgetTester tester) =>
      tester.widget<AppThumbnail>(find.byType(AppThumbnail));

  Uint8List? shownBytes(WidgetTester tester) {
    final image = thumbnail(tester).image;
    return image is MemoryImage ? image.bytes : null;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.pumpAndSettle();
    await showOnScreen(tester, find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> openPhotoSheet(WidgetTester tester, String tooltip) async {
    await showOnScreen(tester, find.byType(AppThumbnail));
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  Future<void> fillManualMeal(WidgetTester tester) async {
    await tester.enterText(fieldLabelled('Nom du repas'), 'Salade niçoise');
    await tester.enterText(tileField('Calories'), '520');
    await tester.pumpAndSettle();
  }

  testWidgets('un repas neuf : la photo prise part APRÈS la création', (
    tester,
  ) async {
    final nutrition = FakeNutritionRepository();
    final picker = FakeMealPhotoPicker(photo: jpeg(200));
    await openMealEditor(
      tester,
      nutrition,
      AppRoutes.newMeal(),
      picker: picker,
    );

    // Sans photo, le dessin violet — et pas encore de « Retirer ».
    expect(thumbnail(tester).image, isNull);
    await openPhotoSheet(tester, 'Ajouter une photo');
    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Choisir dans la galerie'), findsOneWidget);
    expect(find.text('Retirer la photo'), findsNothing);

    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();
    expect(picker.requests, [MealPhotoSource.camera]);
    // La vignette montre la photo AVANT tout envoi : rien n'est parti.
    expect(shownBytes(tester), picker.photo);
    expect(nutrition.photoWrites, isEmpty);

    await fillManualMeal(tester);
    await tapText(tester, 'Ajouter au journal');

    // Le repas d'abord (le faux serveur refuserait une photo sans repas),
    // puis la photo, sous son identifiant, octets intacts.
    final meal = nutrition.meals.single;
    expect(nutrition.writes.single.id, meal.id);
    expect(nutrition.photoWrites.single.id, meal.id);
    expect(nutrition.photoWrites.single.jpeg, picker.photo);
    expect(meal.hasPhoto, isTrue);
    expect(find.byType(MealEditorScreen), findsNothing);
  });

  testWidgets('« Choisir dans la galerie » demande la galerie', (tester) async {
    final picker = FakeMealPhotoPicker(photo: jpeg(90));
    await openMealEditor(
      tester,
      FakeNutritionRepository(),
      AppRoutes.newMeal(),
      picker: picker,
    );
    await openPhotoSheet(tester, 'Ajouter une photo');
    await tester.tap(find.text('Choisir dans la galerie'));
    await tester.pumpAndSettle();

    expect(picker.requests, [MealPhotoSource.gallery]);
    expect(shownBytes(tester), picker.photo);
  });

  testWidgets('pendant la préparation, la vignette attend et rien ne part', (
    tester,
  ) async {
    final picker = FakeMealPhotoPicker(photo: jpeg(120))
      ..hold = Completer<void>();
    final held = picker.hold!;
    await openMealEditor(
      tester,
      FakeNutritionRepository(),
      AppRoutes.newMeal(),
      picker: picker,
    );
    await openPhotoSheet(tester, 'Ajouter une photo');
    await tester.tap(find.text('Prendre une photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(thumbnail(tester).busy, isTrue);
    expect(
      tester.widget<AppCtaButton>(find.byType(AppCtaButton)).onPressed,
      isNull,
      reason: 'on n’enregistre pas un repas dont la photo se prépare',
    );

    held.complete();
    await tester.pumpAndSettle();
    expect(thumbnail(tester).busy, isFalse);
    expect(shownBytes(tester), picker.photo);
  });

  testWidgets('un repas avec photo : les octets du GET dans la vignette, lus '
      'UNE fois pour sa date', (tester) async {
    final served = jpeg(40);
    final nutrition = withLunch(photo: served);
    final router = await pumpMealApp(tester, nutrition);
    unawaited(router.push(AppRoutes.meal('repas-compose')));
    await tester.pumpAndSettle();

    expect(shownBytes(tester), served);
    expect(thumbnail(tester).semanticLabel, 'Photo du plat');
    expect(find.byTooltip('Changer la photo'), findsOneWidget);
    expect(nutrition.photoReads, ['repas-compose']);

    // Refermé puis rouvert : la même date, le cache répond.
    router.pop();
    await tester.pumpAndSettle();
    unawaited(router.push(AppRoutes.meal('repas-compose')));
    await tester.pumpAndSettle();
    expect(shownBytes(tester), served);
    expect(nutrition.photoReads, ['repas-compose']);

    // Enregistré sans y toucher : aucune route de photo n'est appelée.
    await tester.enterText(fieldLabelled('Nom du repas'), 'Déjeuner');
    await tapText(tester, 'Enregistrer la modification');
    expect(nutrition.photoWrites, isEmpty);
  });

  testWidgets('un repas sans photo lisible : le dessin violet, jamais un '
      'trou', (tester) async {
    // Le repas annonce une photo que le serveur n'a plus (404 → `null`).
    await openMealEditor(tester, withLunch(), AppRoutes.meal('repas-compose'));
    expect(thumbnail(tester).image, isNull);
    expect(find.byIcon(AppIcons.mealLunch), findsWidgets);
  });

  group('une photo qui existe mais ne se montre pas', () {
    testWidgets('pendant sa lecture : « en chargement », jamais « pas de '
        'photo »', (tester) async {
      final held = Completer<void>();
      final nutrition = withLunch(photo: jpeg(40))..photoReadHold = held;
      final router = await pumpMealApp(tester, nutrition);
      // Pas d'attente « que tout se pose » : la vignette tourne tant que la
      // photo n'arrive pas.
      unawaited(router.push(AppRoutes.meal('repas-compose')));
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(thumbnail(tester).loading, isTrue);
      expect(thumbnail(tester).semanticLabel, 'Photo du plat, en chargement');
      // Un réseau lent n'empêche pas de changer la photo.
      final button = find.descendant(
        of: find.byType(AppThumbnail),
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(button).tooltip, 'Changer la photo');
      expect(tester.widget<IconButton>(button).onPressed, isNotNull);

      held.complete();
      await tester.pumpAndSettle();
      expect(thumbnail(tester).loading, isFalse);
      expect(thumbnail(tester).semanticLabel, 'Photo du plat');
    });

    for (final (cause, nutrition) in [
      ('introuvable', () => withLunch()),
      (
        'hors connexion',
        () => withLunch(photo: jpeg(40))
          ..photoReadFailure = const NetworkException('Serveur injoignable'),
      ),
    ]) {
      testWidgets('$cause : « indisponible », et la feuille propose de la '
          'retirer', (tester) async {
        await openMealEditor(
          tester,
          nutrition(),
          AppRoutes.meal('repas-compose'),
          picker: FakeMealPhotoPicker(),
        );

        expect(thumbnail(tester).loading, isFalse);
        expect(
          thumbnail(tester).semanticLabel,
          'Photo du plat, indisponible pour l’instant',
        );
        await openPhotoSheet(tester, 'Changer la photo');
        expect(find.text('Retirer la photo'), findsOneWidget);
      });
    }
  });

  testWidgets('la feuille, sur 320 points en texte doublé : chaque choix se '
      'lit en entier', (tester) async {
    tester.view.physicalSize = const Size(960, 1920);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openMealEditor(
      tester,
      withLunch(photo: jpeg(40)),
      AppRoutes.meal('repas-compose'),
      picker: FakeMealPhotoPicker(),
    );
    await openPhotoSheet(tester, 'Changer la photo');

    expect(tester.takeException(), isNull);
    for (final choice in [
      'Prendre une photo',
      'Choisir dans la galerie',
      'Retirer la photo',
    ]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(choice));
      expect(paragraph.didExceedMaxLines, isFalse, reason: choice);
    }
  });

  testWidgets('retirer la photo : le dessin tout de suite, le DELETE à '
      'l’enregistrement', (tester) async {
    final nutrition = withLunch(photo: jpeg(40));
    await openMealEditor(
      tester,
      nutrition,
      AppRoutes.meal('repas-compose'),
      picker: FakeMealPhotoPicker(),
    );
    await openPhotoSheet(tester, 'Changer la photo');
    await tester.tap(find.text('Retirer la photo'));
    await tester.pumpAndSettle();

    expect(thumbnail(tester).image, isNull);
    expect(
      find.text('La photo sera retirée à l’enregistrement du repas.'),
      findsOneWidget,
    );
    expect(nutrition.photoWrites, isEmpty, reason: 'rien ne part avant');

    await tapText(tester, 'Enregistrer la modification');

    expect(nutrition.photoWrites.single.jpeg, isNull);
    expect(nutrition.meals.single.hasPhoto, isFalse);
    expect(find.byType(MealEditorScreen), findsNothing);
  });

  testWidgets('l’envoi échoue : le repas est enregistré, l’écran le dit, et '
      'la photo attend d’être renvoyée', (tester) async {
    final nutrition = FakeNutritionRepository()
      ..photoFailure = const ServerException('panne', statusCode: 503);
    final picker = FakeMealPhotoPicker(photo: jpeg(220));
    await openMealEditor(
      tester,
      nutrition,
      AppRoutes.newMeal(),
      picker: picker,
    );
    await openPhotoSheet(tester, 'Ajouter une photo');
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();
    await fillManualMeal(tester);
    await tapText(tester, 'Ajouter au journal');

    // Le repas EST au journal ; la photo non.
    expect(nutrition.meals.single.name, 'Salade niçoise');
    expect(nutrition.meals.single.hasPhoto, isFalse);
    expect(find.textContaining('mais la photo n’est pas partie'), findsOne);
    // L'écran reste, sur le repas désormais enregistré, la photo en vue.
    expect(find.byType(MealEditorScreen), findsOneWidget);
    expect(find.text('Modifier ce repas'), findsOneWidget);
    expect(shownBytes(tester), picker.photo);

    await tapText(tester, 'Enregistrer la modification');

    expect(nutrition.photoWrites, hasLength(2));
    expect(nutrition.photoWrites.last.jpeg, picker.photo);
    expect(nutrition.meals.single.hasPhoto, isTrue);
    // Toujours UN repas : le second appui a corrigé, pas recréé.
    expect(nutrition.meals, hasLength(1));
    expect(find.byType(MealEditorScreen), findsNothing);
  });

  testWidgets('le RETRAIT échoue : l’écran dit que la photo est toujours là, '
      'et le retrait se retente', (tester) async {
    final nutrition = withLunch(photo: jpeg(40))
      ..photoFailure = const NetworkException('Serveur injoignable');
    await openMealEditor(
      tester,
      nutrition,
      AppRoutes.meal('repas-compose'),
      picker: FakeMealPhotoPicker(),
    );
    await openPhotoSheet(tester, 'Changer la photo');
    await tester.tap(find.text('Retirer la photo'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Enregistrer la modification');

    expect(
      find.text(
        'Repas modifié, mais la photo n’a pas pu être retirée (hors '
        'connexion). Touche « Enregistrer la modification » pour réessayer.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('n’est pas partie'), findsNothing);
    expect(nutrition.meals.single.hasPhoto, isTrue);
    expect(find.byType(MealEditorScreen), findsOneWidget);

    // Le retrait reste demandé : un nouvel appui le retente.
    await tapText(tester, 'Enregistrer la modification');
    expect(nutrition.photoWrites.map((write) => write.jpeg), [null, null]);
    expect(nutrition.meals.single.hasPhoto, isFalse);
    expect(find.byType(MealEditorScreen), findsNothing);
  });

  testWidgets('hors connexion, l’échec de la photo le précise', (tester) async {
    final nutrition = FakeNutritionRepository()
      ..photoFailure = const NetworkException('Serveur injoignable');
    await openMealEditor(
      tester,
      nutrition,
      AppRoutes.newMeal(),
      picker: FakeMealPhotoPicker(photo: jpeg(10)),
    );
    await openPhotoSheet(tester, 'Ajouter une photo');
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();
    await fillManualMeal(tester);
    await tapText(tester, 'Ajouter au journal');

    expect(find.textContaining('(hors connexion)'), findsOneWidget);
  });

  testWidgets('accès refusé : la cause, pas un échec générique', (
    tester,
  ) async {
    final picker = FakeMealPhotoPicker(
      failure: const MealPhotoException(MealPhotoFailure.permissionDenied),
    );
    await openMealEditor(
      tester,
      FakeNutritionRepository(),
      AppRoutes.newMeal(),
      picker: picker,
    );
    await openPhotoSheet(tester, 'Ajouter une photo');
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Carlys n’a pas accès à l’appareil photo'),
      findsOneWidget,
    );
    expect(thumbnail(tester).image, isNull);
    expect(thumbnail(tester).busy, isFalse);
  });

  testWidgets('une image illisible se dit', (tester) async {
    await openMealEditor(
      tester,
      FakeNutritionRepository(),
      AppRoutes.newMeal(),
      picker: FakeMealPhotoPicker(
        failure: const MealPhotoException(MealPhotoFailure.unreadable),
      ),
    );
    await openPhotoSheet(tester, 'Ajouter une photo');
    await tester.tap(find.text('Choisir dans la galerie'));
    await tester.pumpAndSettle();

    expect(
      find.text('Cette image ne se lit pas : choisis-en une autre.'),
      findsOneWidget,
    );
  });

  testWidgets('renoncer à la prise ne change rien', (tester) async {
    final nutrition = withLunch(photo: jpeg(40));
    await openMealEditor(
      tester,
      nutrition,
      AppRoutes.meal('repas-compose'),
      picker: FakeMealPhotoPicker(),
    );
    final before = shownBytes(tester);
    await openPhotoSheet(tester, 'Changer la photo');
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();

    expect(shownBytes(tester), before);
    await tapText(tester, 'Enregistrer la modification');
    expect(nutrition.photoWrites, isEmpty);
  });
}
