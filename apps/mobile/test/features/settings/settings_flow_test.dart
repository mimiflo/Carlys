import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';

Widget app() => ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.development,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
        authRepositoryProvider
            .overrideWithValue(FakeAuthRepository(storedSession: true)),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
      ],
      child: const CarlysApp(),
    );

/// Rend visible un élément de l'écran courant (dernier Scrollable de la pile).
Future<void> reveal(WidgetTester tester, Finder item) async {
  final scrollable = find.byType(Scrollable).last;
  await tester.drag(scrollable, const Offset(0, 2000), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(item, 150, scrollable: scrollable);
  await tester.pumpAndSettle();
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.pumpAndSettle();
  // L'apparence se règle depuis l'onglet Profil.
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomBar),
      matching: find.text('Profil'),
    ),
  );
  await tester.pumpAndSettle();
  // La ligne « Thème sombre » ouvre l'écran d'apparence (l'interrupteur ne
  // bascule que clair ↔ sombre).
  await reveal(tester, find.text('Thème sombre'));
  await tester.tap(find.text('Thème sombre'));
  await tester.pumpAndSettle();
}

ThemeMode themeModeOf(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  setUp(() {
    // Les scènes 3D (cœur, hélice) bouclent en continu : réduction
    // d'animations pour que pumpAndSettle converge.
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  setUp(() {
    // Parcours de première ouverture déjà terminé.
    seedCompletedFirstRun();
  });

  testWidgets('thème sombre : appliqué immédiatement et persisté',
      (tester) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    // Dark-first : sombre par défaut.
    expect(themeModeOf(tester), ThemeMode.dark);

    await tester.tap(find.text('Clair'));
    await tester.pumpAndSettle();
    expect(themeModeOf(tester), ThemeMode.light);

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();

    expect(themeModeOf(tester), ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('apparence.theme'), 'dark');
  });

  testWidgets('thème sombre OLED : fond noir pur', (tester) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    await tester.tap(find.text('Sombre OLED'));
    await tester.pumpAndSettle();

    expect(themeModeOf(tester), ThemeMode.dark);
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      materialApp.darkTheme!.scaffoldBackgroundColor,
      AppColors.oledBackground,
    );
  });

  testWidgets('préférence restaurée au démarrage', (tester) async {
    seedCompletedFirstRun({'apparence.theme': 'light'});

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(themeModeOf(tester), ThemeMode.light);
  });
}
