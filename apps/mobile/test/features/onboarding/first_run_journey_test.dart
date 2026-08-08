import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/onboarding/domain/first_run_step.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/onboarding_height_card.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_nutrition_repository.dart';
import '../../support/fake_progress_repository.dart';
import '../../support/fake_subscription_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';

/// PARCOURS DE PREMIÈRE OUVERTURE : onboarding → création de compte →
/// proposition Premium → repli gratuit → accueil, puis réouvertures.
///
/// Le tunnel est entièrement piloté par la redirection du routeur : ces
/// tests montent l'application complète et ne naviguent qu'au doigt.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository auth;
  late FakeNutritionRepository nutrition;

  setUp(() {
    seedFirstOpen();
    // Les écrans traversés portent des scènes 3D en boucle : sans réduction
    // d'animations, pumpAndSettle ne rendrait jamais la main.
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    auth = FakeAuthRepository();
    nutrition = FakeNutritionRepository();
  });

  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  Widget app() => ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(
              flavor: AppFlavor.development,
              apiBaseUrl: 'http://localhost:3000',
            ),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          nutritionRepositoryProvider.overrideWithValue(nutrition),
          subscriptionRepositoryProvider
              .overrideWithValue(FakeSubscriptionRepository()),
          progressRepositoryProvider
              .overrideWithValue(FakeProgressRepository()),
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
        ],
        child: const CarlysApp(),
      );

  /// Démarre l'application sur un écran de téléphone (les cartes de
  /// l'onboarding ont besoin de hauteur).
  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// Répond aux 4 étapes de l'onboarding puis valide.
  Future<void> answerOnboarding(WidgetTester tester) async {
    await tapText(tester, 'Prendre du muscle');
    await tapText(tester, 'Continuer');

    await tapText(tester, 'Homme');
    await tapText(tester, 'Continuer');

    await tapText(tester, 'Date de naissance');
    await tapText(tester, 'OK');
    await tester.tap(
      find.descendant(
        of: find.byType(OnboardingHeightCard),
        matching: find.byIcon(AppIcons.add),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'Continuer');

    await tapText(tester, 'Actif');
    await tapText(tester, 'Terminer');
  }

  Future<void> fillRegisterForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Camille');
    await tester.enterText(fields.at(1), 'camille@example.com');
    await tester.enterText(fields.at(2), 'MotDePasseSolide42');
    await tapText(tester, 'Créer mon compte');
  }

  testWidgets(
      'première ouverture : onboarding → inscription → Premium → gratuit → '
      'accueil', (tester) async {
    await launch(tester);

    // 1. L'application s'ouvre sur l'onboarding, pas sur l'accueil.
    expect(find.text('1/4'), findsOneWidget);
    expect(find.byType(AppBottomBar), findsNothing);

    await answerOnboarding(tester);

    // 2. Création de compte. Sans session, rien n'a encore été envoyé au
    // serveur : les réponses attendent le compte.
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(nutrition.updateCount, 0);

    await fillRegisterForm(tester);

    // 3. Proposition Premium : vrai temps d'arrêt, sans croix de fermeture,
    // avec les droits réels du serveur.
    expect(find.text('CARLYS PREMIUM'), findsOneWidget);
    expect(find.byIcon(AppIcons.close), findsNothing);
    expect(find.text('Programmes illimités'), findsOneWidget);
    expect(find.text('Passer à Premium'), findsOneWidget);

    // Les réponses d'onboarding sont reportées sur le profil dès que le
    // compte existe.
    expect(nutrition.updateCount, 1);
    final report = await nutrition.metabolismReport();
    expect(report.profile.goal, NutritionGoal.gainMuscle);
    expect(report.profile.sex, BiologicalSex.male);
    expect(report.profile.heightCm, 176);
    expect(report.profile.activityLevel, ActivityLevel.active);

    // 4. Refus : la version gratuite est proposée explicitement, puis
    // l'application s'ouvre.
    await tapText(tester, 'Continuer sans Premium');
    expect(find.text('Continuer en version gratuite ?'), findsOneWidget);

    await tapText(tester, 'Continuer en version gratuite');
    expect(find.byType(AppBottomBar), findsOneWidget);

    // 5. Réouverture : le tunnel ne se rejoue pas.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.text('1/4'), findsNothing);
  });

  testWidgets('le refus mène à Premium puis revient : aucune impasse',
      (tester) async {
    seedFirstRunStep(FirstRunStep.subscription);
    auth.storedSession = true;
    await launch(tester);

    expect(find.text('CARLYS PREMIUM'), findsOneWidget);

    // « Passer à Premium » explique où souscrire — aucun tarif inventé.
    await tapText(tester, 'Passer à Premium');
    expect(find.textContaining('App Store'), findsOneWidget);
    await tapText(tester, 'J’ai compris');

    // Le repli gratuit se rétracte aussi.
    await tapText(tester, 'Continuer sans Premium');
    await tapText(tester, 'Revenir à Premium');
    expect(find.text('Passer à Premium'), findsOneWidget);

    await tapText(tester, 'Continuer sans Premium');
    await tapText(tester, 'Continuer en version gratuite');
    expect(find.byType(AppBottomBar), findsOneWidget);
  });

  testWidgets('« Passer » franchit l’onboarding sans rien enregistrer',
      (tester) async {
    await launch(tester);

    await tapText(tester, 'Passer');

    expect(nutrition.updateCount, 0);
    expect(find.text('Créer un compte'), findsOneWidget);
  });

  testWidgets('depuis l’onboarding, la connexion reste accessible',
      (tester) async {
    await launch(tester);

    await tapText(tester, 'J’ai déjà un compte');
    expect(find.text('Connexion'), findsOneWidget);

    // Connexion réussie : le parcours reprend là où il en était.
    await tester.enterText(
      find.byType(TextFormField).first,
      'camille@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'MotDePasseSolide42',
    );
    await tapText(tester, 'Se connecter');

    expect(auth.loginCalls, 1);
    expect(find.text('1/4'), findsOneWidget);
    // Session ouverte : le lien de connexion n'a plus lieu d'être.
    expect(find.text('J’ai déjà un compte'), findsNothing);
  });

  testWidgets('réouverture au milieu du tunnel : reprise à l’étape atteinte',
      (tester) async {
    seedFirstRunStep(FirstRunStep.account);
    await launch(tester);

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('1/4'), findsNothing);

    // Qui a déjà un compte rejoint la connexion depuis l'inscription.
    await tapText(tester, 'Se connecter');
    expect(find.text('Connexion'), findsOneWidget);
  });

  testWidgets(
      'parcours terminé et session ouverte : jamais renvoyé dans le tunnel',
      (tester) async {
    seedCompletedFirstRun();
    auth.storedSession = true;
    await launch(tester);

    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.text('1/4'), findsNothing);
    expect(find.text('CARLYS PREMIUM'), findsNothing);
  });
}
