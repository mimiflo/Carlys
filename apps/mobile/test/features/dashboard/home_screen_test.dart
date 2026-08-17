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
/// de constance sous le cœur, les quatre mesures d'aujourd'hui, la séance à
/// lancer, puis la forme du jour adossée aux séances de la semaine.
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

  testWidgets('en-tête et forme du jour', (tester) async {
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

    await scrollTo(tester, find.text('FORME DU JOUR'));
    expect(find.text('FORME DU JOUR'), findsOneWidget);
    // 2 séances sur les 5 visées : le score et la bande où il tombe.
    expect(find.text('40 / 100'), findsOneWidget);
    expect(find.text('Prêt pour du lourd'), findsOneWidget);
    expect(find.text('CHARGE JUSTE'), findsOneWidget);
    expect(find.text('séances / 5 cette semaine'), findsOneWidget);
  });

  testWidgets('aujourd’hui : chaque mesure face à sa cible', (tester) async {
    await pumpHome(tester);

    await scrollTo(tester, find.text('AUJOURD’HUI'));
    expect(find.text('CALORIES'), findsOneWidget);
    expect(find.text('PROTÉINES'), findsOneWidget);
    expect(find.text('HYDRATATION'), findsOneWidget);
    expect(find.text('VOLUME'), findsOneWidget);

    // Journal vide : un VRAI zéro face à l'objectif, et le reste qui en
    // découle — jamais un objectif déguisé en consommé.
    expect(find.text('/ 2\u202F759 kcal'), findsOneWidget);
    expect(find.text('reste 2\u202F759 kcal'), findsOneWidget);
    expect(find.text('/ 128 g'), findsOneWidget);
    expect(find.text('reste 128 g'), findsOneWidget);

    // L'eau bue n'est pas suivie : la cible est réelle, la valeur reste en
    // attente plutôt qu'inventée.
    expect(find.text('à noter dans Nutrition'), findsOneWidget);

    // Aucune semaine précédente ici : pas de cible de volume, donc pas de
    // « reste » — la portée de la mesure prend sa place.
    expect(find.text('cette semaine'), findsOneWidget);
  });

  testWidgets('le consommé du journal s’affiche face à l’objectif',
      (tester) async {
    // Les repas sont ancrés sur la JOURNÉE en cours, jamais sur « il y a
    // N heures » : passé minuit, un décalage relatif bascule la veille et le
    // total du jour change sous les pieds du test.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nutrition = completeNutrition()
      ..meals.addAll([
        MealEntry(
          id: 'repas-1',
          name: 'Skyr',
          kcal: 380,
          eatenAt: today.add(const Duration(hours: 8)),
        ),
        MealEntry(
          id: 'repas-2',
          name: 'Poulet riz',
          kcal: 274,
          eatenAt: today.add(const Duration(hours: 12)),
        ),
      ]);
    await pumpHome(tester, nutrition: nutrition);

    await scrollTo(tester, find.text('AUJOURD’HUI'));
    // 380 + 274 = 654 : le consommé et le reste sont des faits, pas des
    // inventions.
    expect(find.text('654'), findsOneWidget);
    expect(find.text('/ 2\u202F759 kcal'), findsOneWidget);
    expect(find.text('reste 2\u202F105 kcal'), findsOneWidget);
  });

  testWidgets(
    'sans séance en cours : entraînement libre et tuiles',
    (tester) async {
      await pumpHome(tester);

      await scrollTo(tester, find.text('Entraînement libre'));
      expect(find.text('SÉANCE DU JOUR'), findsOneWidget);
      expect(find.text('Entraînement libre'), findsOneWidget);
      expect(
        find.text('Tu choisis les exercices en cours de route.'),
        findsOneWidget,
      );
      // Le disque n'a pas de libellé écrit : c'est la sémantique qui le porte.
      expect(
        find.semantics.byLabel('Démarrer la séance'),
        findsOneWidget,
        reason: 'le disque doit rester atteignable au lecteur d’écran',
      );
      // La seconde porte, hors séance seulement.
      expect(find.text('Lancer un modèle'), findsOneWidget);
    },
    semanticsEnabled: true,
  );

  testWidgets('la citation du jour vit à gauche du cœur', (tester) async {
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

    // La forme du jour, elle, est bien descendue hors de la zone haute.
    expect(
      find.descendant(of: hero, matching: find.text('FORME DU JOUR')),
      findsNothing,
    );
  });

  testWidgets('la citation descend jusqu’à la série de constance',
      (tester) async {
    await pumpHome(tester);

    final quote = tester.getRect(find.byType(DailyQuoteCard));
    final streak = tester.getRect(find.byType(ConsistencyStreak));

    // Elle s'arrête juste au-dessus, à une gouttière près : ni bloc riquiqui
    // flottant en haut, ni chevauchement.
    expect(quote.bottom, lessThan(streak.top));
    expect(streak.top - quote.bottom, lessThan(AppSpacing.gapSection));

    // Et elle occupe vraiment la bande laissée par le cœur.
    expect(quote.height, greaterThan(100));
  });

  testWidgets('série de constance : sept jours, L M M J V S D', (tester) async {
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

    // La série s'annonce dans la barre de titre, en capitales.
    expect(find.text('2 JOURS'), findsOneWidget);
    // DEUX flammes exactement : celle de la barre de titre, et la flamme
    // vivante qui ne brûle que tant que la série tient. Les jours tenus, eux,
    // sont des traits — pas une rangée de petits feux.
    expect(
      find.descendant(
        of: find.byType(ConsistencyStreak),
        matching: find.byIcon(AppIcons.streak),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets(
    'séance en cours : titre, durée écoulée et reprise',
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
      await scrollTo(tester, find.text('Push force'));

      // Le nom de la séance ne s'écrit plus qu'à UN endroit : la grille du
      // jour mesure, elle ne redit pas ce que la carte au-dessus annonce.
      expect(find.text('Push force'), findsOneWidget);
      // Durée écoulée et faits mesurés tiennent dans une seule phrase.
      expect(
        find.text('En cours depuis 52 min — 1 exercice, 2 séries.'),
        findsOneWidget,
      );
      expect(find.semantics.byLabel('Reprendre la séance'), findsOneWidget);
      // On ne lance pas une séance quand une autre est ouverte.
      expect(find.text('Lancer un modèle'), findsNothing);
    },
    semanticsEnabled: true,
  );
}
