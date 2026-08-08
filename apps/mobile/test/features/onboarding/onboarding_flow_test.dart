import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/onboarding_height_card.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_nutrition_repository.dart';
import '../../support/fake_workout_repository.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // L'écran porte une scène 3D en boucle : sans réduction d'animations,
    // pumpAndSettle ne rendrait jamais la main.
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  Future<FakeNutritionRepository> openOnboarding(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final nutrition = FakeNutritionRepository();
    await tester.pumpWidget(
      ProviderScope(
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
          nutritionRepositoryProvider.overrideWithValue(nutrition),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(AppBottomBar)))
        .go(AppRoutes.onboarding);
    await tester.pumpAndSettle();
    return nutrition;
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
  }

  testWidgets('la première étape masque le retour et bloque le CTA',
      (tester) async {
    await openOnboarding(tester);

    expect(find.text('1/4'), findsOneWidget);
    expect(find.byIcon(AppIcons.back), findsNothing);
    expect(find.text('TON OBJECTIF'), findsOneWidget);
    expect(find.text('Prendre du muscle'), findsOneWidget);
    expect(find.text('Surplus léger · volume élevé'), findsOneWidget);

    // Aucune réponse choisie : le CTA ne fait rien.
    await tapContinue(tester);
    expect(find.text('1/4'), findsOneWidget);
  });

  testWidgets('choisir une réponse marque la carte et débloque le CTA',
      (tester) async {
    await openOnboarding(tester);

    expect(find.byIcon(AppIcons.checkCircle), findsNothing);
    await tester.tap(find.text('Prendre du muscle'));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.checkCircle), findsOneWidget);

    await tapContinue(tester);
    expect(find.text('2/4'), findsOneWidget);
    expect(find.text('TON PROFIL'), findsOneWidget);
  });

  testWidgets('le retour ramène à l’étape précédente', (tester) async {
    await openOnboarding(tester);

    await tester.tap(find.text('Prendre du muscle'));
    await tester.pumpAndSettle();
    await tapContinue(tester);

    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();
    expect(find.text('1/4'), findsOneWidget);
    // La réponse déjà donnée reste sélectionnée.
    expect(find.byIcon(AppIcons.checkCircle), findsOneWidget);
  });

  testWidgets('les 4 étapes enregistrent le profil métabolique réel',
      (tester) async {
    final nutrition = await openOnboarding(tester);

    await tester.tap(find.text('Prendre du muscle'));
    await tester.pumpAndSettle();
    await tapContinue(tester);

    await tester.tap(find.text('Homme'));
    await tester.pumpAndSettle();
    await tapContinue(tester);

    expect(find.text('TES MESURES'), findsOneWidget);
    await tester.tap(find.text('Date de naissance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // La taille doit être touchée pour valider l'étape.
    expect(find.text('Continuer'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(OnboardingHeightCard),
        matching: find.byIcon(AppIcons.add),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('176 cm'), findsOneWidget);
    await tapContinue(tester);

    expect(find.text('TON RYTHME'), findsOneWidget);
    expect(find.text('3 à 5 séances par semaine'), findsOneWidget);
    await tester.tap(find.text('Actif'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();

    expect(nutrition.updateCount, 1);
    final report = await nutrition.metabolismReport();
    expect(report.profile.goal, NutritionGoal.gainMuscle);
    expect(report.profile.sex, BiologicalSex.male);
    expect(report.profile.heightCm, 176);
    expect(report.profile.activityLevel, ActivityLevel.active);
    // Retour à l'accueil une fois le profil enregistré.
    expect(find.byType(AppBottomBar), findsOneWidget);
  });

  testWidgets('« Passer » revient à l’accueil sans rien enregistrer',
      (tester) async {
    final nutrition = await openOnboarding(tester);

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();

    expect(nutrition.updateCount, 0);
    expect(find.byType(AppBottomBar), findsOneWidget);
  });
}
