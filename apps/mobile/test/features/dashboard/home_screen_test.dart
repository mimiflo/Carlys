import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/design_system/scenes/heart_scene.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/dashboard/data/daily_quotes.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/consistency_streak.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/daily_quote_card.dart';
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
    FakeNutritionRepository? nutrition,
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
          nutritionRepositoryProvider
              .overrideWithValue(nutrition ?? completeNutrition()),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// La page est plus longue que l'écran et la ListView est PARESSEUSE : une
  /// section basse n'existe pas tant qu'on ne l'a pas atteinte.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      240,
      scrollable: find.byType(Scrollable).first,
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

    expect(find.text('Bonjour, Camille.'), findsOneWidget);
    // La phrase d'état est adossée au seul fait connu : 30 h de récupération.
    expect(
      find.text('Récupération faite : le créneau est bon.'),
      findsOneWidget,
    );

    await scrollTo(tester, find.text('INDICE DE FORME'));
    expect(find.text('INDICE DE FORME'), findsOneWidget);
    // 2 séances sur les 5 visées.
    expect(find.text('40'), findsOneWidget);
    expect(find.text('Prêt pour du lourd'), findsOneWidget);
  });

  testWidgets('résumé du jour : quatre faits réels, aucun inventé',
      (tester) async {
    await pumpHome(tester);

    await scrollTo(tester, find.text('RÉSUMÉ DU JOUR'));
    expect(find.text('RÉSUMÉ DU JOUR'), findsOneWidget);
    expect(find.text('ENTRAÎNEMENT'), findsOneWidget);
    expect(find.text('NUTRITION'), findsOneWidget);
    expect(find.text('PROTÉINES'), findsOneWidget);
    expect(find.text('VOLUME'), findsOneWidget);

    // Journal vide : un VRAI zéro face à l'objectif — « 0 / 2 759 », pas
    // un objectif déguisé en consommé. Les protéines restent un objectif.
    expect(find.text('0 / 2\u202F759'), findsOneWidget);
    expect(find.text('kcal aujourd’hui'), findsOneWidget);
    expect(find.text('128 g'), findsOneWidget);
    expect(find.text('objectif du jour'), findsOneWidget);
    expect(find.text('1,5 t'), findsOneWidget);
    expect(find.text('cette semaine'), findsOneWidget);

    // Aucune séance faite aujourd'hui dans ce cas.
    expect(find.text('À faire'), findsOneWidget);

    // Ce que la maquette de référence montre mais que le domaine ignore.
    expect(find.text('SOMMEIL'), findsNothing);
    expect(find.text('HYDRATATION'), findsNothing);
  });

  testWidgets('le consommé du journal s’affiche face à l’objectif',
      (tester) async {
    final nutrition = completeNutrition()
      ..meals.addAll([
        MealEntry(
          id: 'repas-1',
          name: 'Skyr',
          kcal: 380,
          eatenAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        MealEntry(
          id: 'repas-2',
          name: 'Poulet riz',
          kcal: 274,
          eatenAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ]);
    await pumpHome(tester, nutrition: nutrition);

    await scrollTo(tester, find.text('RÉSUMÉ DU JOUR'));
    // 380 + 274 = 654 : le « 654 / 2 759 » est un fait, pas une invention.
    expect(find.text('654 / 2\u202F759'), findsOneWidget);
    expect(find.text('kcal aujourd’hui'), findsOneWidget);
  });

  testWidgets('sans séance en cours : entraînement libre et tuiles',
      (tester) async {
    await pumpHome(tester);

    await scrollTo(tester, find.text('Entraînement libre'));
    expect(find.text('SÉANCE DU JOUR'), findsOneWidget);
    expect(find.text('Entraînement libre'), findsOneWidget);
    expect(find.text('Démarrer la séance'), findsOneWidget);

    await scrollTo(tester, find.text('Ta semaine'));
    expect(find.text('Ta semaine'), findsOneWidget);
    expect(find.text('2 / 5 SÉANCES'), findsOneWidget);
  });

  testWidgets('la citation du jour est en carte, à gauche du cœur',
      (tester) async {
    await pumpHome(tester);

    expect(find.text('CITATION DU JOUR'), findsOneWidget);

    // Celle du jour, exactement — c'est le câblage qu'on vérifie ici ; la
    // règle de rotation a ses propres tests.
    final today = quoteOfTheDay(DateTime.now());
    expect(find.text(today.text), findsOneWidget);
    // La valeur Carlys ordonne la rotation, elle ne s'affiche pas.
    expect(find.text(today.value.label), findsNothing);

    // Elle vit DANS la zone haute, au même niveau que le cœur — mais dans
    // la colonne de gauche, jamais sur la masse de la scène.
    final hero = find.byType(HomeHero);
    expect(
      find.descendant(of: hero, matching: find.text(today.text)),
      findsOneWidget,
    );
    expect(find.byType(HeartScene), findsOneWidget);

    // Le canvas de la scène est LARGEMENT transparent sur son bord gauche
    // (masque radial) : la carte peut mordre sur sa boîte sans toucher au
    // cœur. Ce qu'on garantit, c'est qu'elle n'atteint jamais sa masse.
    final quote = tester.getRect(find.byType(DailyQuoteCard));
    final scene = tester.getRect(find.byType(HeartScene));
    expect(quote.right, lessThan(scene.center.dx));

    // L'indice de forme, lui, est bien descendu hors de la zone haute.
    expect(
      find.descendant(of: hero, matching: find.text('INDICE DE FORME')),
      findsNothing,
    );
  });

  testWidgets('la carte de citation descend jusqu’à la série de constance',
      (tester) async {
    await pumpHome(tester);

    final quote = tester.getRect(find.byType(DailyQuoteCard));
    final streak = tester.getRect(find.byType(ConsistencyStreak));

    // Elle s'arrête juste au-dessus, à une gouttière près : ni carte
    // riquiqui flottant en haut, ni chevauchement.
    expect(quote.bottom, lessThan(streak.top));
    expect(streak.top - quote.bottom, lessThan(AppSpacing.gapSection));

    // Et elle occupe vraiment la bande : plus haute que large.
    expect(quote.height, greaterThan(quote.width));
  });

  testWidgets('série de constance : sept jours en ronds, L M M J V S D',
      (tester) async {
    await pumpHome(tester);

    // Elle vit SOUS la zone haute, la colonne de gauche revenant à la
    // citation.
    expect(find.text('SÉRIE DE CONSTANCE'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomeHero),
        matching: find.byType(ConsistencyStreak),
      ),
      findsNothing,
    );

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

    expect(find.text('Jour 2'), findsOneWidget);
    // Une flamme par jour tenu de la semaine affichée, PLUS celle qui
    // accompagne « Jour N ». Les deux jours ne débordent sur la semaine
    // précédente que le lundi et le mardi.
    final expectedFlames = 1 +
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
          name: 'Push force',
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

    // Deux fois : la carte « séance du jour » ET la tuile ENTRAÎNEMENT du
    // résumé, qui reflète la séance en cours.
    expect(find.text('Push force'), findsNWidgets(2));
    expect(find.text('en cours'), findsOneWidget);
    expect(find.text('52 MIN'), findsOneWidget);
    expect(find.text('1 exercice'), findsOneWidget);
    expect(find.text('2 séries'), findsOneWidget);
    expect(find.text('Reprendre la séance'), findsOneWidget);
  });
}
