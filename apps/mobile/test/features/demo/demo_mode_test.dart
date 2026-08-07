import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/demo/demo_overrides.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_workout_repository.dart';

/// Le mode démo doit ouvrir l'application SANS serveur : session déjà
/// ouverte, catalogue, progression et nutrition servis en mémoire.
/// (Le dépôt de séances reste réel — Drift — donc doublé ici comme dans
/// tous les tests de widgets.)
Widget demoApp() => ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.demo,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
        ...demoOverrides(),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
      ],
      child: const CarlysApp(),
    );

Future<void> reveal(WidgetTester tester, Finder item) async {
  final scrollable = find.byType(Scrollable).last;
  await tester.drag(scrollable, const Offset(0, 2000), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(item, 150, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('démarre connecté, sans réseau', (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Visiteur'), findsWidgets);
  });

  testWidgets('bibliothèque servie en mémoire', (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text('Exercices'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Développé couché'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
  });

  testWidgets('nutrition complète servie en mémoire', (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text('Nutrition'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OBJECTIF QUOTIDIEN'), findsOneWidget);
    expect(
      find.textContaining('3040', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('progression et abonnement premium servis en mémoire',
      (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text('Progrès'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Séances'), findsOneWidget);

    // L'abonnement se rejoint depuis l'onglet Profil.
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text('Profil'),
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Abonnement'));
    await tester.tap(find.text('Abonnement'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Premium (démo)'), findsWidgets);
  });
}
