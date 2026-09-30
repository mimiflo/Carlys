import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/presentation/providers/water_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_water_store.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/local_data_overrides.dart';
import '../../support/navigation.dart';

Widget app() => ProviderScope(
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
    waterStoreProvider.overrideWithValue(FakeWaterStore()),
    syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
    appRestoreProvider.overrideWithValue(NoopAppRestore()),
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
  // L'apparence se règle dans les réglages, derrière le rouage du profil
  // — lui-même ouvert par l'avatar de l'accueil.
  await openProfileSettings(tester);
  await reveal(tester, find.text('Apparence'));
  await tester.tap(find.text('Apparence'));
  await tester.pumpAndSettle();
}

/// Le thème que les écrans lisent RÉELLEMENT, pas celui qu'on a déclaré :
/// sous `ThemeMode.system`, un thème clair déclaré s'appliquerait à un
/// téléphone réglé en clair — le harnais l'est.
ThemeData themeOf(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Navigator).first));

void main() {
  setUp(() {
    // Les scènes 3D (cœur, hélice) bouclent en continu : réduction
    // d'animations pour que pumpAndSettle converge.
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  setUp(() {
    // Parcours de première ouverture déjà terminé.
    seedCompletedFirstRun();
  });

  testWidgets('deux thèmes, tous deux sombres : Sombre par défaut, Sombre '
      'OLED au noir pur, chacun appliqué et persisté', (tester) async {
    await tester.pumpWidget(app());
    await openSettings(tester);

    // Les thèmes Clair et Système ont été retirés (décision du 27 septembre
    // 2026) : il n'en reste que deux.
    expect(find.text('Clair'), findsNothing);
    expect(find.text('Système'), findsNothing);
    expect(themeOf(tester).brightness, Brightness.dark);
    expect(themeOf(tester).scaffoldBackgroundColor, AppColors.darkBackground);

    await tester.tap(find.text('Sombre OLED'));
    await tester.pumpAndSettle();
    expect(themeOf(tester).scaffoldBackgroundColor, AppColors.oledBackground);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('apparence.theme'), 'oled');

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();
    expect(themeOf(tester).scaffoldBackgroundColor, AppColors.darkBackground);
    expect(prefs.getString('apparence.theme'), 'dark');
  });

  for (final ancienne in ['light', 'system']) {
    testWidgets('préférence « $ancienne » enregistrée avant le retrait : lue '
        'comme Sombre', (tester) async {
      seedCompletedFirstRun({'apparence.theme': ancienne});

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(themeOf(tester).brightness, Brightness.dark);
      expect(themeOf(tester).scaffoldBackgroundColor, AppColors.darkBackground);
    });
  }

  testWidgets('préférence « Sombre OLED » restaurée au démarrage', (
    tester,
  ) async {
    seedCompletedFirstRun({'apparence.theme': 'oled'});

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(themeOf(tester).scaffoldBackgroundColor, AppColors.oledBackground);
  });
}
