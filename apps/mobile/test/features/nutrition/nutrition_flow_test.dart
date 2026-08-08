import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/dna_helix.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_nutrition_repository.dart';
import '../../support/fake_workout_repository.dart';

Widget appWith(FakeNutritionRepository nutrition) => ProviderScope(
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
        nutritionRepositoryProvider.overrideWithValue(nutrition),
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

Future<void> openNutrition(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomBar),
      matching: find.text('Nutrition'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('réduction d’animations active (hélice statique)', () {
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
    });

    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .clearAccessibilityFeaturesTestValue();
    });

    testWidgets('profil incomplet : manquants listés et formulaire affiché',
        (tester) async {
      await tester.pumpWidget(appWith(FakeNutritionRepository()));
      await openNutrition(tester);

      expect(find.text('Informations manquantes'), findsOneWidget);
      expect(find.text('Sexe biologique'), findsWidgets);
      expect(find.text('Poids (mesure corporelle)'), findsOneWidget);
      expect(find.byType(DnaHelix), findsOneWidget);
      // Le poids manque : l'app renvoie vers les mesures corporelles.
      await reveal(tester, find.textContaining('mesures corporelles'));
      expect(find.textContaining('mesures corporelles'), findsOneWidget);
    });

    testWidgets('formulaire complété : le rapport métabolique apparaît',
        (tester) async {
      final nutrition = FakeNutritionRepository(weightKg: 80);
      await tester.pumpWidget(appWith(nutrition));
      await openNutrition(tester);

      await reveal(tester, find.text('Homme'));
      await tester.tap(find.text('Homme'));
      await tester.pumpAndSettle();

      await reveal(tester, find.text('Choisir une date'));
      await tester.tap(find.text('Choisir une date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await reveal(tester, find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), '180');

      await reveal(tester, find.text('Choisir un niveau'));
      await tester.tap(find.byType(DropdownButtonFormField<ActivityLevel>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Modérément actif').last);
      await tester.pumpAndSettle();

      await reveal(tester, find.text('Enregistrer mon profil'));
      await tester.tap(find.text('Enregistrer mon profil'));
      await tester.pumpAndSettle();

      expect(nutrition.updateCount, 1);
      // Dépense totale du hero et objectif de l'en-tête « Macros » : les
      // milliers sont séparés par une espace fine insécable.
      expect(
        find.textContaining('2\u202F759', findRichText: true),
        findsWidgets,
      );
      expect(find.text('Macros'), findsOneWidget);
      expect(find.textContaining('OBJECTIF'), findsOneWidget);
      expect(find.text('128 g'), findsOneWidget);
      expect(find.text('CORPULENCE NORMALE'), findsOneWidget);
    });

    testWidgets('profil complet : résultats, IMC et hydratation affichés',
        (tester) async {
      await tester.pumpWidget(
        appWith(
          FakeNutritionRepository(
            weightKg: 80,
            sex: BiologicalSex.male,
            birthDate: DateTime.utc(1996, 3, 12),
            heightCm: 180,
            activityLevel: ActivityLevel.moderate,
            goal: NutritionGoal.maintain,
          ),
        ),
      );
      await openNutrition(tester);

      expect(find.textContaining('OBJECTIF'), findsOneWidget);
      expect(find.text('24,7'), findsOneWidget);
      await reveal(tester, find.textContaining('2,8'));
      expect(find.textContaining('2,8'), findsWidgets);
      // L'objectif nutritionnel reste lisible dans le formulaire de profil.
      await reveal(tester, find.text('Maintenir'));
      expect(find.text('Maintenir'), findsWidgets);
      // Le profil reste modifiable sous les résultats.
      await reveal(tester, find.text('Enregistrer mon profil'));
      expect(find.text('Enregistrer mon profil'), findsOneWidget);
    });
  });

  testWidgets('hélice ADN : animation en boucle par défaut', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DnaHelix())),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DnaHelix), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
    // Bounded pumps uniquement : l'animation ne « settle » jamais.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('hélice ADN : statique quand les animations sont réduites',
      (tester) async {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
    addTearDown(
      TestWidgetsFlutterBinding
          .instance.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DnaHelix())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DnaHelix), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
