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
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:carlys_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/presentation/screens/progress_screen.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
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

/// L'onglet Coach dans la coquille.
///
/// Le piège d'une barre à index : la barre rend un rang, la coquille ouvre la
/// branche du même rang. Insérer un onglet au milieu décale tout ce qui suit,
/// et un décalage d'un cran est invisible à la lecture du code. Ce test tape
/// chaque onglet et vérifie qu'il ouvre bien le sien.
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

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la barre porte six onglets, dont Coach au centre',
      (tester) async {
    await pumpApp(tester, FakeCoachRepository());

    expect(appBottomBarItems, hasLength(6));
    expect(appBottomBarItems[2].label, 'Coach');
    expect(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text('Coach'),
      ),
      findsOneWidget,
    );
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

    await tapTab(tester, 'Coach');
    expect(find.byType(CoachPage), findsOneWidget);
    expect(find.text('Coach IA'), findsOneWidget);
    expect(find.text('On reprend où on s’est arrêtés.'), findsOneWidget);

    // Les onglets qui SUIVENT le nouveau venu sont ceux qui risquaient le
    // décalage : ce sont eux qu'on vérifie, un par un.
    await tapTab(tester, 'Progrès');
    expect(find.byType(ProgressScreen), findsOneWidget);

    await tapTab(tester, 'Nutrition');
    expect(find.byType(NutritionScreen), findsOneWidget);

    await tapTab(tester, 'Profil');
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('ouvrir l’onglet pour regarder ne crée pas de fil vide',
      (tester) async {
    final coach = FakeCoachRepository();
    await pumpApp(tester, coach);

    await tapTab(tester, 'Coach');

    expect(find.text('Ton coach est là'), findsOneWidget);
    expect(coach.createdConversations, isEmpty);
  });
}
