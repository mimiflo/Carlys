import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/dashboard/data/daily_quotes.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/consistency_streak.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/home_hero.dart';
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

/// Accueil : l'écran ne montre que des faits réels — maxime du jour et série
/// de constance sous le cœur, séance du jour, tuiles, puis l'indice de forme
/// adossé à « Ta semaine ».
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
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
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

  testWidgets('sous le cœur : la maxime du jour, pas un chiffre',
      (tester) async {
    await pumpHome(tester);

    // Celle du jour, exactement — c'est le câblage qu'on vérifie ici ; la
    // règle de rotation a ses propres tests.
    final today = quoteOfTheDay(DateTime.now());
    expect(find.text(today.text), findsOneWidget);
    expect(
      find.text(today.value.label.toUpperCase()),
      findsOneWidget,
    );

    // La maxime est DANS la zone haute, l'indice de forme n'y est plus.
    final hero = find.byType(HomeHero);
    expect(
      find.descendant(of: hero, matching: find.text(today.text)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hero, matching: find.text('INDICE DE FORME')),
      findsNothing,
    );
  });

  testWidgets('série de constance : sept jours en ronds, L M M J V S D',
      (tester) async {
    await pumpHome(tester);

    expect(find.text('Ta constance'), findsOneWidget);

    final streak = find.byType(ConsistencyStreak);
    Finder dayOf(String initial) =>
        find.descendant(of: streak, matching: find.text(initial));

    expect(dayOf('L'), findsOneWidget);
    expect(dayOf('M'), findsNWidgets(2)); // mardi et mercredi
    expect(dayOf('J'), findsOneWidget);
    expect(dayOf('V'), findsOneWidget);
    expect(dayOf('S'), findsOneWidget);
    expect(dayOf('D'), findsOneWidget);
  });

  testWidgets('une flamme par jour tenu, et la série annoncée', (tester) async {
    // Deux jours consécutifs tenus, en terminant hier : la série court
    // toujours puisque la journée en cours n'est pas finie.
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final before = DateTime(today.year, today.month, today.day - 2);
    final workouts = FakeWorkoutRepository()
      ..history = [
        for (final (index, day) in [yesterday, before].indexed)
          WorkoutHistoryEntry(
            session: WorkoutInfo(
              id: 'w-$index',
              status: WorkoutStatus.completed,
              startedAt: day.add(const Duration(hours: 18)),
              endedAt: day.add(const Duration(hours: 19)),
              syncState: LocalSyncState.synced,
            ),
            setsCount: 5,
            totalVolumeKg: 700,
          ),
      ];

    await pumpHome(tester, workouts: workouts);

    expect(find.text('2 JOURS D’AFFILÉE'), findsOneWidget);
    // Une flamme par jour tenu de la semaine affichée : les deux jours ne
    // débordent sur la semaine précédente que le lundi et le mardi.
    final expectedFlames =
        [yesterday, before].where((day) => day.weekday <= today.weekday).length;
    expect(
      find.descendant(
        of: find.byType(ConsistencyStreak),
        matching: find.byIcon(AppIcons.streak),
      ),
      findsNWidgets(expectedFlames),
    );
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
