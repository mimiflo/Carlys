// Galerie d'écrans de l'app — OUTIL DE CAPTURE, exécuté à la demande :
//   flutter test tool/screenshots --update-goldens
// Volontairement HORS de test/ : la CI ne compare jamais ces rendus
// (fragiles entre versions de moteur) ; les PNG générés sont ignorés par git.
//
// Ce fichier EST un harnais de test (exécuté via `flutter test`), simplement
// rangé hors de test/ — l'avertissement visible_for_testing est donc infondé :
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:carlys_mobile/features/coaching/domain/entities/coach.dart';
import 'package:carlys_mobile/features/coaching/presentation/controllers/coach_controllers.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_card.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/onboarding/domain/first_run_step.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/brand_signature.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/welcome_backdrop.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_plan_card.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/body_weight_section.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test/support/fake_auth_repository.dart';
import '../../test/support/fake_coach_repository.dart';
import '../../test/support/fake_exercises_repository.dart';
import '../../test/support/fake_nutrition_repository.dart';
import '../../test/support/fake_progress_repository.dart';
import '../../test/support/fake_subscription_repository.dart';
import '../../test/support/fake_workout_repository.dart';
import '../../test/support/first_run_prefs.dart';

Future<void> loadRealFonts() async {
  // Polices du bundle (MaterialIcons…).
  final manifest = await rootBundle.loadStructuredData<List<dynamic>>(
    'FontManifest.json',
    (data) async => json.decode(data) as List<dynamic>,
  );
  for (final entry in manifest.whereType<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    // LIMITE CONNUE : `FontLoader` n'expose aucun poids, et le harnais ne sait
    // donc pas choisir la graisse — c'est la PREMIÈRE fonte chargée qui sert à
    // tous les poids, les autres étant simulées. Les captures sous-rendent donc
    // le gras : mesuré, « TON PARCOURS. » en 24/w700 fait 192 px ici contre
    // ~211 sur un vrai appareil. On charge le 400 en tête, le plus proche de la
    // moyenne de l'interface — sans quoi une fonte fine déclarée en premier
    // amaigrirait toute la galerie.
    final fonts = (entry['fonts'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) {
        int gap(Map<String, dynamic> f) => ((f['weight'] as int?) ?? 400) - 400;
        return gap(a).abs().compareTo(gap(b).abs());
      });
    for (final font in fonts) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }

  // Roboto depuis le cache du SDK : rendu de texte réaliste (la police de
  // test « blocs » fausse largeurs et lisibilité des captures).
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final fontsDir =
        Directory('$flutterRoot/bin/cache/artifacts/material_fonts');
    // « FlutterTest » est la police par défaut du harnais (glyphes en blocs) :
    // la remplacer aussi rend les styles sans famille explicite lisibles.
    for (final family in const ['Roboto', 'FlutterTest']) {
      final loader = FontLoader(family);
      for (final file in fontsDir.listSync().whereType<File>()) {
        if (file.path.endsWith('.ttf') && file.path.contains('Roboto-')) {
          loader.addFont(
            file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        }
      }
      await loader.load();
    }
  }
}

FakeExercisesRepository catalogOf() => FakeExercisesRepository(
      [
        summary('id-1', 'Développé couché', group: 'pectoraux'),
        summary('id-2', 'Squat', group: 'quadriceps'),
        summary('id-3', 'Tractions', group: 'dos'),
        summary('id-4', 'Soulevé de terre', group: 'lombaires'),
        summary('id-5', 'Pompes', group: 'pectoraux'),
      ],
      pageSize: 10,
    );

WorkoutWithSets activeWorkoutOf() {
  WorkoutSetEntry set(int position, String name, int reps, double weight) =>
      WorkoutSetEntry(
        id: 'set-$position',
        exerciseName: name,
        position: position,
        kind: position == 0 ? SetKind.warmup : SetKind.normal,
        reps: reps,
        weightKg: weight,
        restSeconds: 90,
        completedAt: DateTime.utc(2026, 8, 7, 10, 5 + position * 3),
        syncState:
            position < 2 ? LocalSyncState.synced : LocalSyncState.pending,
      );
  return WorkoutWithSets(
    session: WorkoutInfo(
      id: 'session-1',
      name: 'Push A',
      status: WorkoutStatus.inProgress,
      startedAt: DateTime.utc(2026, 8, 7, 10),
      syncState: LocalSyncState.synced,
    ),
    sets: [
      set(0, 'Développé couché', 12, 40),
      set(1, 'Développé couché', 10, 60),
      set(2, 'Développé couché', 8, 70),
    ],
  );
}

List<WorkoutHistoryEntry> historyOf() {
  WorkoutHistoryEntry entry(int day, String name, int sets, double volume) =>
      WorkoutHistoryEntry(
        session: WorkoutInfo(
          id: 'h-$day',
          name: name,
          status: WorkoutStatus.completed,
          startedAt: DateTime.utc(2026, 8, day, 9),
          syncState: LocalSyncState.synced,
        ),
        setsCount: sets,
        totalVolumeKg: volume,
      );
  return [
    entry(7, 'Push A', 14, 2140),
    entry(6, 'Legs', 12, 3260),
    entry(4, 'Pull A', 15, 1980),
    entry(2, 'Push B', 13, 2050),
    entry(1, 'Full body', 10, 1720),
  ];
}

FakeProgressRepository progressOf() => FakeProgressRepository(
      records: [
        recordOf('Développé couché', PersonalRecordType.maxWeight, 80),
        recordOf('Développé couché', PersonalRecordType.maxReps, 12),
        recordOf('Développé couché', PersonalRecordType.maxSetVolume, 700),
        recordOf('Squat', PersonalRecordType.maxWeight, 120),
      ],
      bodyMetrics: [
        for (final (index, value)
            in [86.0, 85.2, 84.6, 84.9, 83.8, 83.1, 82.5].indexed)
          BodyMetricEntry(
            id: 'w-$index',
            kind: BodyMetricKind.weightKg,
            value: value,
            measuredAt:
                DateTime.utc(2026, 6, 25).add(Duration(days: index * 6)),
          ),
      ],
    );

/// Conversation d'exemple de la galerie : une question, une réponse, et la
/// séance qui en découle — c'est l'enchaînement que l'écran doit montrer.
FakeCoachRepository coachOf() {
  const proposal = CoachSessionProposal(
    id: 'p1',
    name: 'Haut du corps — format court',
    estimatedMinutes: 28,
    exercises: [
      CoachProposedExercise(
        name: 'Développé couché',
        setCount: 3,
        detail: '8 reps · 70 kg',
      ),
      CoachProposedExercise(name: 'Tractions', setCount: 3, detail: '6 reps'),
      CoachProposedExercise(
        name: 'Développé militaire',
        setCount: 3,
        detail: '10 reps · 35 kg',
      ),
    ],
  );

  return FakeCoachRepository(
    threads: [
      CoachConversationSummary(
        id: 'thread-1',
        title: 'Séance courte',
        messagesCount: 4,
        updatedAt: DateTime.utc(2026, 8, 9),
      ),
    ],
    messages: const [
      CoachMessage(
        id: 'm1',
        role: CoachRole.user,
        content: 'J’ai seulement 30 minutes aujourd’hui.',
      ),
      CoachMessage(
        id: 'm2',
        role: CoachRole.assistant,
        content: 'On garde les deux mouvements principaux et on resserre les '
            'repos. Les charges ne bougent pas : c’est le volume qui tombe, '
            'pas l’intensité.',
        proposal: proposal,
      ),
    ],
  );
}

FakeNutritionRepository nutritionOf({bool complete = true}) => complete
    ? FakeNutritionRepository(
        weightKg: 82.5,
        sex: BiologicalSex.male,
        birthDate: DateTime.utc(1996, 3, 12),
        heightCm: 180,
        activityLevel: ActivityLevel.moderate,
        goal: NutritionGoal.gainMuscle,
      )
    : FakeNutritionRepository(weightKg: 82.5);

void main() {
  setUpAll(loadRealFonts);

  setUp(() {
    // Galerie d'une app déjà installée : le parcours de première ouverture
    // est terminé, sinon toutes les captures repartiraient du tunnel.
    seedCompletedFirstRun();
  });

  // Les scènes 3D bouclent en continu : pumps BORNÉS uniquement, calés
  // sur le pic de systole du battement (~80 ms) pour de belles captures.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 80));
  }

  /// Décode les images du bundle AVANT la capture.
  ///
  /// Le harnais de test fait tourner un temps FICTIF : le décodage d'une image,
  /// lui, est du vrai travail asynchrone, et ne s'achève jamais tant qu'on
  /// n'ouvre pas une fenêtre de temps réel. Sans ça, les écrans à photographie
  /// se capturent vides — et la capture ment.
  Future<void> precacheBrandImages(WidgetTester tester) async {
    final context = tester.element(find.byType(MaterialApp));
    for (final asset in const [
      BrandSignature.markAsset,
      WelcomeBackdrop.athleteAsset,
    ]) {
      await tester.runAsync(
        () => precacheImage(AssetImage(asset), context),
      );
    }
    await settle(tester);
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    bool authenticated = true,
    FakeExercisesRepository? exercises,
    FakeWorkoutRepository? workouts,
    FakeNutritionRepository? nutrition,
    FakeCoachRepository? coach,
    bool premium = false,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
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
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(storedSession: authenticated),
          ),
          exercisesRepositoryProvider.overrideWithValue(
            exercises ?? catalogOf(),
          ),
          workoutRepositoryProvider.overrideWithValue(
            workouts ?? FakeWorkoutRepository(),
          ),
          progressRepositoryProvider.overrideWithValue(progressOf()),
          nutritionRepositoryProvider.overrideWithValue(
            nutrition ?? nutritionOf(),
          ),
          subscriptionRepositoryProvider.overrideWithValue(
            FakeSubscriptionRepository(isPremium: premium),
          ),
          coachRepositoryProvider.overrideWithValue(
            coach ?? FakeCoachRepository(),
          ),
          // Les puces se calculent depuis les modèles de séance, qui vivent
          // dans Drift : la galerie n'ouvre pas de base locale, elle fige donc
          // le résultat que la règle donnerait pour ce jeu d'exemple.
          coachSuggestionsProvider.overrideWithValue(const [
            'Adapte « Push A » à 30 minutes',
            'Comment continuer sur Développé couché ?',
          ]),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
        ],
        child: const CarlysApp(),
      ),
    );
    await settle(tester);
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  Future<void> goTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text(label),
      ),
    );
    await settle(tester);
  }

  testWidgets('bienvenue', (tester) async {
    // Parcours de première ouverture NON franchi : la page de marque est la
    // toute première chose que voit un nouvel arrivant.
    seedFirstRunStep(FirstRunStep.welcome);
    await pumpApp(tester, authenticated: false);
    await precacheBrandImages(tester);
    await capture(tester, '00-bienvenue');
  });

  testWidgets('connexion', (tester) async {
    await pumpApp(tester, authenticated: false);
    await capture(tester, '01-connexion');
  });

  testWidgets('accueil', (tester) async {
    // Un historique est nécessaire : sans lui, la série de constance
    // s'afficherait vide et la capture ne montrerait pas la fonctionnalité.
    await pumpApp(
      tester,
      workouts: FakeWorkoutRepository()..history = historyOf(),
    );
    await capture(tester, '02-accueil');
  });

  testWidgets('bibliothèque + fiche exercice', (tester) async {
    await pumpApp(tester);
    await goTab(tester, 'Exercices');
    await capture(tester, '03-bibliotheque');

    await tester.tap(find.widgetWithText(ExerciseCard, 'Squat'));
    await settle(tester);
    await capture(tester, '04-fiche-exercice');
  });

  testWidgets('séance active', (tester) async {
    final workouts = FakeWorkoutRepository()..active = activeWorkoutOf();
    await pumpApp(tester, workouts: workouts);
    await tester.tap(find.text('Reprendre la séance'));
    await settle(tester);
    await capture(tester, '05-seance-active');
  });

  testWidgets('onglet coach', (tester) async {
    await pumpApp(tester, coach: coachOf(), premium: true);
    await goTab(tester, 'Coach');
    await capture(tester, '18-coach-onglet');
  });

  testWidgets('progression', (tester) async {
    await pumpApp(tester);
    await goTab(tester, 'Progrès');
    await capture(tester, '06-progression');

    await tester.scrollUntilVisible(
      find.byType(BodyWeightSection),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await capture(tester, '07-progression-poids');
  });

  testWidgets('abonnement premium', (tester) async {
    await pumpApp(tester, premium: true);
    await goTab(tester, 'Profil');
    await tester.tap(find.byType(ProfilePlanCard));
    await settle(tester);
    await capture(tester, '08-abonnement');
  });

  testWidgets('nutrition — métabolisme complet', (tester) async {
    await pumpApp(tester);
    await goTab(tester, 'Nutrition');
    await capture(tester, '10-nutrition-metabolisme');

    await tester.scrollUntilVisible(
      find.text('Macros'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await capture(tester, '11-nutrition-macros');
  });

  testWidgets('nutrition — profil à compléter', (tester) async {
    await pumpApp(tester, nutrition: nutritionOf(complete: false));
    await goTab(tester, 'Nutrition');
    await capture(tester, '12-nutrition-profil');
  });

  testWidgets('profil + réglages + thème clair', (tester) async {
    await pumpApp(tester, premium: true);
    await goTab(tester, 'Profil');
    await capture(tester, '13-profil');

    await tester.scrollUntilVisible(find.text('Thème sombre'), 150);
    await settle(tester);
    await tester.tap(find.text('Thème sombre'));
    await settle(tester);
    await capture(tester, '14-reglages');
  });

  testWidgets('historique', (tester) async {
    final workouts = FakeWorkoutRepository()..history = historyOf();
    await pumpApp(tester, workouts: workouts);
    final context = tester.element(find.byType(AppBottomBar));
    unawaited(GoRouter.of(context).push(AppRoutes.history));
    await settle(tester);
    await capture(tester, '15-historique');
  });

  testWidgets('onboarding', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(AppBottomBar));
    GoRouter.of(context).go(AppRoutes.onboarding);
    await settle(tester);
    await capture(tester, '16-onboarding');
  });

  testWidgets('paywall exercice premium', (tester) async {
    final gated = _PremiumGated([summary('id-1', 'Balancier kettlebell')]);
    await pumpApp(tester, exercises: gated);
    await goTab(tester, 'Exercices');
    await tester.tap(find.text('Balancier kettlebell'));
    await settle(tester);
    await capture(tester, '09-exercice-premium');
  });
}

class _PremiumGated extends FakeExercisesRepository {
  _PremiumGated(super.all) : super(pageSize: 10);

  @override
  Future<ExerciseDetail> byIdOrSlug(String idOrSlug) {
    return Future.error(
      const ForbiddenException('Exercice réservé aux membres Premium.'),
    );
  }
}
