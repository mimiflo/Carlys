// Captures du Plan 4, tranche 1 (objectif d'entraînement) — OUTIL :
//   flutter test tool/screenshots/objectif_test.dart --update-goldens
//
// Comme les autres fichiers de ce dossier, il est HORS de test/ : la CI ne
// compare jamais ces rendus, et les PNG sont ignorés par git.
//
// Ce fichier EST un harnais de test (exécuté via `flutter test`), simplement
// rangé hors de test/ — l'avertissement visible_for_testing est donc infondé :
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/onboarding/domain/first_run_step.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_settings_sections.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/presentation/controllers/training_goal_controllers.dart';
import 'package:carlys_mobile/features/workout_program/presentation/widgets/training_goal_sheet.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/fake_auth_repository.dart';
import '../../test/support/fake_workout_repository.dart';
import '../../test/support/first_run_prefs.dart';
import 'capture_test.dart' show loadRealFonts;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRealFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  void telephone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('onboarding : l’étape « Ton entraînement », réponse choisie', (
    tester,
  ) async {
    telephone(tester);
    // Appareil arrêté à l'étape onboarding : le routeur y démarre SANS
    // construire l'accueil (qui ouvrirait Drift et le réseau du test).
    seedFirstRunStep(FirstRunStep.onboarding);
    await tester.pumpWidget(
      ProviderScope(
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
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Jusqu'à l'étape 2 : identité choisie, puis l'objectif d'entraînement.
    await tester.tap(find.text('LE CONSTRUCTEUR'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('TON ENTRAÎNEMENT'), findsOneWidget);
    await tester.tap(find.text('Recomposition'));
    await tester.pumpAndSettle();
    await capture(tester, 'objectif-01-onboarding');

    // `testWidgets` refuse un minuteur en vol à la fin du corps, et vérifie
    // AVANT de démonter l'arbre : on démonte soi-même puis on laisse filer
    // un instant — même purge que la galerie (`capture_test.dart`).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('profil : la feuille « Ton objectif d’entraînement »', (
    tester,
  ) async {
    telephone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTrainingGoalProvider.overrideWithValue(TrainingGoal.hyrox),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SafeArea(
              child: Builder(
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: Stack(
                    children: [
                      // Le groupe d'où la feuille s'ouvre : du contenu
                      // plausible derrière elle, jamais un écran noir.
                      ProfileTrainingSettings(
                        goalLabel: TrainingGoal.hyrox.label,
                        onGoal: () {},
                        onTemplates: () {},
                        onHistory: () {},
                        onBodyMetrics: () {},
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: TextButton(
                          onPressed: () => showTrainingGoalSheet(context),
                          child: const Text('ouvrir'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Ton objectif d’entraînement'), findsOneWidget);
    await capture(tester, 'objectif-02-feuille');
  });
}
