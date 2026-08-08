import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_nutrition_repository.dart';
import '../../support/fake_progress_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';

/// Accueil : l'écran ne montre que des faits réels — indice de forme déduit
/// de la semaine, faits d'entraînement, séance du jour, tuiles et semaine.
void main() {
  setUp(() {
    // Parcours de première ouverture déjà terminé : l'application démarre
    // sur l'accueil.
    seedCompletedFirstRun();
    // La scène cœur boucle en continu : réduction d'animations pour que
    // pumpAndSettle converge.
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  FakeNutritionRepository completeNutrition() => FakeNutritionRepository(
        weightKg: 80,
        sex: BiologicalSex.male,
        birthDate: DateTime.utc(1996, 3, 12),
        heightCm: 180,
        activityLevel: ActivityLevel.moderate,
        goal: NutritionGoal.gainMuscle,
      );

  Future<void> pumpHome(
    WidgetTester tester, {
    FakeWorkoutRepository? workouts,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

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
          workoutRepositoryProvider
              .overrideWithValue(workouts ?? FakeWorkoutRepository()),
          progressRepositoryProvider
              .overrideWithValue(FakeProgressRepository()),
          nutritionRepositoryProvider.overrideWithValue(completeNutrition()),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('en-tête, indice de forme et faits de la semaine',
      (tester) async {
    final workouts = FakeWorkoutRepository()
      ..history = [
        WorkoutHistoryEntry(
          session: WorkoutInfo(
            id: 'w-1',
            status: WorkoutStatus.completed,
            startedAt: DateTime.now().subtract(const Duration(hours: 31)),
            endedAt: DateTime.now().subtract(const Duration(hours: 30)),
            syncState: LocalSyncState.synced,
          ),
          setsCount: 6,
          totalVolumeKg: 840,
        ),
      ];

    await pumpHome(tester, workouts: workouts);

    expect(find.text('Bonjour,\nCamille'), findsOneWidget);
    expect(find.text('INDICE DE FORME'), findsOneWidget);
    // 2 séances sur les 5 visées.
    expect(find.text('40'), findsOneWidget);
    expect(find.text('Prêt pour du lourd'), findsOneWidget);

    // Faits réels : récupération, séances et volume de la semaine.
    expect(find.text('RÉCUP OK'), findsOneWidget);
    expect(find.text('2 SÉANCES'), findsOneWidget);
    expect(find.text('1,5 T'), findsOneWidget);
  });

  testWidgets('sans séance en cours : entraînement libre et tuiles',
      (tester) async {
    await pumpHome(tester);

    expect(find.text('SÉANCE DU JOUR'), findsOneWidget);
    expect(find.text('Entraînement libre'), findsOneWidget);
    expect(find.text('Démarrer la séance'), findsOneWidget);

    expect(find.text('KCAL'), findsOneWidget);
    expect(find.text('PROTÉINES'), findsOneWidget);
    expect(find.text('VOLUME'), findsOneWidget);
    expect(find.text('2 759', findRichText: true), findsOneWidget);
    expect(find.text('128g', findRichText: true), findsOneWidget);
    expect(find.text('1,5t', findRichText: true), findsOneWidget);

    expect(find.text('Ta semaine'), findsOneWidget);
    expect(find.text('2 / 5 SÉANCES'), findsOneWidget);
  });

  testWidgets('séance en cours : titre, durée écoulée et reprise',
      (tester) async {
    final startedAt = DateTime.now().subtract(const Duration(minutes: 52));
    final workouts = FakeWorkoutRepository()
      ..active = WorkoutWithSets(
        session: WorkoutInfo(
          id: 'w-2',
          name: 'Push — Force',
          status: WorkoutStatus.inProgress,
          startedAt: startedAt,
          syncState: LocalSyncState.pending,
        ),
        sets: [
          WorkoutSetEntry(
            id: 's-1',
            exerciseName: 'Développé couché',
            position: 1,
            kind: SetKind.normal,
            reps: 8,
            weightKg: 80,
            completedAt: startedAt,
            syncState: LocalSyncState.pending,
          ),
          WorkoutSetEntry(
            id: 's-2',
            exerciseName: 'Développé couché',
            position: 2,
            kind: SetKind.normal,
            reps: 8,
            weightKg: 80,
            completedAt: startedAt,
            syncState: LocalSyncState.pending,
          ),
        ],
      );

    await pumpHome(tester, workouts: workouts);

    expect(find.text('Push — Force'), findsOneWidget);
    expect(find.text('52 MIN'), findsOneWidget);
    expect(find.text('1 exercice'), findsOneWidget);
    expect(find.text('2 séries'), findsOneWidget);
    expect(find.text('Reprendre la séance'), findsOneWidget);
  });
}
