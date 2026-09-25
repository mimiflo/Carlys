/// Le HARNAIS de l'écran de repas : l'écran sur un vrai routeur, au-dessus
/// d'une page d'accueil nue, avec le dépôt nutrition en mémoire.
///
/// Un vrai routeur, parce que l'écran se referme par la navigation : un
/// enregistrement réussi doit RAMENER à la page d'avant, et c'est ce que les
/// tests vérifient. Les chemins sont ceux d'`AppRoutes`, pour que les
/// portes d'entrée (le journal) s'y retrouvent.
library;

import 'dart:async';

import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/data/services/image_picker_meal_photo_picker.dart';
import 'package:carlys_mobile/features/nutrition/domain/services/meal_photo_picker.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/meal_editor_screen.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/meal_journal_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_nutrition_repository.dart';

/// La page d'où l'on part : le journal du jour, comme dans l'application.
const String mealHomeRoute = '/';

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(
      path: mealHomeRoute,
      builder: (_, _) => const Scaffold(
        body: SingleChildScrollView(
          child: MealJournalSection(targetKcal: 2000),
        ),
      ),
    ),
    GoRoute(
      path: '${AppRoutes.nutrition}/repas/nouveau',
      builder: (_, state) => MealEditorScreen(
        day: DateTime.tryParse(state.uri.queryParameters['jour'] ?? ''),
      ),
    ),
    GoRoute(
      path: '${AppRoutes.nutrition}/repas/:mealId',
      builder: (_, state) =>
          MealEditorScreen(mealId: state.pathParameters['mealId']),
    ),
  ],
);

/// Monte l'application de test, sur le journal.
///
/// [picker] remplace l'appareil photo et la galerie : sans lui, un test qui
/// toucherait « Prendre une photo » appellerait le vrai greffon.
Future<GoRouter> pumpMealApp(
  WidgetTester tester,
  FakeNutritionRepository nutrition, {
  MealPhotoPicker? picker,
}) async {
  final router = _router();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nutritionRepositoryProvider.overrideWithValue(nutrition),
        if (picker != null) mealPhotoPickerProvider.overrideWithValue(picker),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Ouvre l'écran de repas sur [location], par-dessus le journal : comme
/// depuis ses portes, avec une page à laquelle revenir.
Future<void> openMealEditor(
  WidgetTester tester,
  FakeNutritionRepository nutrition,
  String location, {
  MealPhotoPicker? picker,
}) async {
  final router = await pumpMealApp(tester, nutrition, picker: picker);
  // `push` rend un futur qui ne se termine qu'au RETOUR : ne pas l'attendre.
  unawaited(router.push(location));
  await tester.pumpAndSettle();
}

/// La case de saisie d'un champ nommé [label] (« Nom du repas »).
Finder fieldLabelled(String label) => find.descendant(
  of: find.widgetWithText(AppTextField, label),
  matching: find.byType(TextField),
);

/// La case d'une tuile de valeur (« Calories », « Protéines »…).
Finder tileField(String label) => find.descendant(
  of: find.widgetWithText(AppNutrientTile, label),
  matching: find.byType(TextField),
);

/// Amène [target] à l'écran : la page défile.
Future<void> showOnScreen(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
