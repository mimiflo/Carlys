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
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/onboarding/domain/first_run_step.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_training_settings.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/program_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/training_profile_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_profile.dart';
import 'package:carlys_mobile/features/workout_program/presentation/controllers/training_goal_controllers.dart';
import 'package:carlys_mobile/features/workout_program/presentation/screens/training_setup_screen.dart';
import 'package:carlys_mobile/features/workout_program/presentation/widgets/training_goal_sheet.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/fake_auth_repository.dart';
import '../../test/support/fake_exercises_repository.dart';
import '../../test/support/fake_program_repository.dart';
import '../../test/support/fake_training_profile_repository.dart';
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
                        onSetup: () {},
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

  testWidgets('« Préparer mon programme » : entrées remplies', (tester) async {
    telephone(tester);
    final repo = FakeTrainingProfileRepository(
      initial: const TrainingProfile(
        goal: TrainingGoal.hyrox,
        experience: TrainingExperience.intermediate,
        weeklySessionsTarget: 4,
        sessionMinutesTarget: 60,
        equipmentSlugs: ['barre', 'halteres', 'poids-du-corps'],
      ),
    );
    final exercises = FakeExercisesRepository(const [])
      ..equipmentRefs = const [
        EquipmentRef(id: 'e1', slug: 'barre', name: 'Barre'),
        EquipmentRef(id: 'e2', slug: 'banc', name: 'Banc'),
        EquipmentRef(id: 'e3', slug: 'elastiques', name: 'Élastiques'),
        EquipmentRef(id: 'e4', slug: 'halteres', name: 'Haltères'),
        EquipmentRef(id: 'e5', slug: 'kettlebell', name: 'Kettlebell'),
        EquipmentRef(id: 'e6', slug: 'poids-du-corps', name: 'Poids du corps'),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingProfileRepositoryProvider.overrideWithValue(repo),
          exercisesRepositoryProvider.overrideWithValue(exercises),
          programRepositoryProvider.overrideWithValue(FakeProgramRepository()),
          currentTrainingGoalProvider.overrideWithValue(TrainingGoal.hyrox),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: const TrainingSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Préparer mon programme'), findsOneWidget);
    await capture(tester, 'objectif-03-preparation');

    // Le bas de l'écran : rythme, durée et matériel coché.
    await tester.scrollUntilVisible(
      find.text('Poids du corps'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture(tester, 'objectif-04-materiel');

    // Le bas de l'écran : le bouton « Générer », prêt puisque les cinq
    // réponses sont là.
    await tester.scrollUntilVisible(
      find.text('Tout est prêt'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture(tester, 'objectif-05-generer');

    // Et ce que la génération RÉPOND : le plan avec son explication.
    await tester.tap(find.text('Générer mon programme'));
    await tester.pumpAndSettle();
    await capture(tester, 'objectif-06-rapport');
  });
}
