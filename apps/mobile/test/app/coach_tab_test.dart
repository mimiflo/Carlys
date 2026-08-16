import 'dart:ui' show Size;

import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/controllers/coach_controllers.dart';
import 'package:carlys_mobile/features/coaching/presentation/screens/coach_page.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_composer.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:carlys_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/presentation/screens/progress_screen.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/training/presentation/screens/training_hub_screen.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_coach_repository.dart';
import '../support/fake_nutrition_repository.dart';
import '../support/fake_progress_repository.dart';
import '../support/fake_subscription_repository.dart';
import '../support/fake_workout_repository.dart';
import '../support/first_run_prefs.dart';
import '../support/navigation.dart';

/// Le coach DANS la coquille.
///
/// Le piège d'une barre à index : la barre rend un rang, la coquille ouvre la
/// branche du même rang. Insérer un onglet au milieu décale tout ce qui suit,
/// et un décalage d'un cran est invisible à la lecture du code. Ce test tape
/// chaque onglet et vérifie qu'il ouvre bien le sien.
///
/// Deux propriétés du coach n'existent QUE dans la coquille, et ne peuvent
/// donc se vérifier qu'ici : la flèche qui ramène au hub Training, et la
/// place de la barre de saisie, qui se règle sur la barre d'onglets puis sur
/// le clavier.
void main() {
  setUp(() {
    seedCompletedFirstRun();
    // Les scènes 3D bouclent en continu : sans réduction d'animations,
    // pumpAndSettle ne converge jamais.
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  Future<void> pumpApp(WidgetTester tester, FakeCoachRepository coach) async {
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
          coachRepositoryProvider.overrideWithValue(coach),
          progressRepositoryProvider
              .overrideWithValue(FakeProgressRepository()),
          nutritionRepositoryProvider
              .overrideWithValue(FakeNutritionRepository()),
          subscriptionRepositoryProvider
              .overrideWithValue(FakeSubscriptionRepository(isPremium: true)),
          coachSuggestionsProvider
              .overrideWithValue(const ['Par où je commence ?']),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la barre porte cinq onglets — le coach vit dans Training',
      (tester) async {
    await pumpApp(tester, FakeCoachRepository());

    expect(appBottomBarItems, hasLength(5));
    expect(
      appBottomBarItems.map((item) => item.label),
      ['Accueil', 'Training', 'Progrès', 'Academy', 'Communauté'],
    );
    // Le coach n'est plus un onglet : il s'ouvre depuis le hub Training.
    await tapTab(tester, 'Training');
    expect(find.text('Coach IA'), findsOneWidget);
  });

  testWidgets('chaque onglet ouvre le sien — aucun décalage d’index',
      (tester) async {
    await pumpApp(
      tester,
      FakeCoachRepository(
        threads: [
          CoachConversationSummary(
            id: 'thread-1',
            messagesCount: 1,
            updatedAt: DateTime.utc(2026, 8, 9),
          ),
        ],
        messages: const [
          CoachMessage(
            id: 'm1',
            role: CoachRole.assistant,
            content: 'On reprend où on s’est arrêtés.',
          ),
        ],
      ),
    );

    await openCoach(tester);
    expect(find.byType(CoachPage), findsOneWidget);
    expect(find.text('On reprend où on s’est arrêtés.'), findsOneWidget);

    // Chaque onglet ouvre le sien — c'est l'appariement barre/branche qu'on
    // éprouve, l'erreur classique après une réorganisation.
    await tapTab(tester, 'Progrès');
    expect(find.byType(ProgressScreen), findsOneWidget);

    await openNutrition(tester);
    expect(find.byType(NutritionScreen), findsOneWidget);

    await openProfile(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('ouvrir l’onglet pour regarder ne crée pas de fil vide',
      (tester) async {
    final coach = FakeCoachRepository();
    await pumpApp(tester, coach);

    await openCoach(tester);

    expect(find.text('Ton coach est là'), findsOneWidget);
    expect(coach.createdConversations, isEmpty);
  });

  testWidgets('la flèche de retour ramène au hub Training', (tester) async {
    // Le coach se pousse depuis une carte du hub : il y a un écran derrière,
    // donc une flèche pour y revenir. Sans elle, il faudrait ressortir par la
    // barre d'onglets, c'est-à-dire quitter Training pour y retourner.
    await pumpApp(tester, FakeCoachRepository());
    await openCoach(tester);

    expect(find.byTooltip('Retour'), findsOneWidget);

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    expect(find.byType(TrainingHubScreen), findsOneWidget);
    expect(find.byType(CoachPage), findsNothing);
  });

  testWidgets(
      'la barre de saisie reste en bas, puis passe AU-DESSUS du '
      'clavier', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpApp(tester, FakeCoachRepository());
    await openCoach(tester);

    final composer = find.byType(CoachComposer);
    final barTop = tester.getRect(find.byType(AppBottomBar)).top;

    // Clavier fermé : posée juste au-dessus de la barre d'onglets, à un
    // écart de respiration près. Ni derrière elle, ni flottant plus haut.
    expect(barTop - tester.getRect(composer).bottom, closeTo(AppSpacing.md, 1));

    const keyboard = 320.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
    await tester.pumpAndSettle();

    // Clavier ouvert : elle passe juste au-dessus de lui, et la réserve de
    // la barre d'onglets s'efface — le clavier la recouvre déjà. La compter
    // à la main la laisserait en trop, et la saisie flotterait.
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getRect(composer).bottom,
      closeTo(screenHeight - keyboard - AppSpacing.md, 1),
    );
  });
}
