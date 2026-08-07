// Galerie d'écrans de l'app — OUTIL DE CAPTURE, exécuté à la demande :
//   flutter test tool/screenshots --update-goldens
// Volontairement HORS de test/ : la CI ne compare jamais ces rendus
// (fragiles entre versions de moteur) ; les PNG générés sont ignorés par git.
//
// Ce fichier EST un harnais de test (exécuté via `flutter test`), simplement
// rangé hors de test/ — l'avertissement visible_for_testing est donc infondé :
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'dart:io';

import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_card.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/fake_auth_repository.dart';
import '../../test/support/fake_exercises_repository.dart';
import '../../test/support/fake_nutrition_repository.dart';
import '../../test/support/fake_progress_repository.dart';
import '../../test/support/fake_subscription_repository.dart';
import '../../test/support/fake_workout_repository.dart';

Future<void> loadRealFonts() async {
  // Polices du bundle (MaterialIcons…).
  final manifest = await rootBundle.loadStructuredData<List<dynamic>>(
    'FontManifest.json',
    (data) async => json.decode(data) as List<dynamic>,
  );
  for (final entry in manifest.whereType<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()) {
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
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    bool authenticated = true,
    FakeExercisesRepository? exercises,
    FakeWorkoutRepository? workouts,
    FakeNutritionRepository? nutrition,
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
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  Future<void> goHomeButton(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('connexion', (tester) async {
    await pumpApp(tester, authenticated: false);
    await capture(tester, '01-connexion');
  });

  testWidgets('accueil', (tester) async {
    await pumpApp(tester);
    await capture(tester, '02-accueil');
  });

  testWidgets('bibliothèque + fiche exercice', (tester) async {
    await pumpApp(tester);
    await goHomeButton(tester, 'Bibliothèque d’exercices');
    await capture(tester, '03-bibliotheque');

    await tester.tap(find.widgetWithText(ExerciseCard, 'Squat'));
    await tester.pumpAndSettle();
    await capture(tester, '04-fiche-exercice');
  });

  testWidgets('séance active', (tester) async {
    final workouts = FakeWorkoutRepository()..active = activeWorkoutOf();
    await pumpApp(tester, workouts: workouts);
    await goHomeButton(tester, 'Reprendre la séance');
    await capture(tester, '05-seance-active');
  });

  testWidgets('progression', (tester) async {
    await pumpApp(tester);
    await goHomeButton(tester, 'Progression');
    await capture(tester, '06-progression');

    await tester.scrollUntilVisible(
      find.text('82.5 kg'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await capture(tester, '07-progression-poids');
  });

  testWidgets('abonnement premium', (tester) async {
    await pumpApp(tester, premium: true);
    await goHomeButton(tester, 'Abonnement');
    await capture(tester, '08-abonnement');
  });

  // L'hélice ADN tourne en boucle : pumps bornés uniquement (jamais
  // pumpAndSettle une fois l'écran nutrition affiché).
  Future<void> goNutrition(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Nutrition'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nutrition'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('nutrition — métabolisme complet', (tester) async {
    await pumpApp(tester);
    await goNutrition(tester);
    await capture(tester, '10-nutrition-metabolisme');

    await tester.scrollUntilVisible(
      find.text('Macro-nutriments'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await capture(tester, '11-nutrition-macros');
  });

  testWidgets('nutrition — profil à compléter', (tester) async {
    await pumpApp(tester, nutrition: nutritionOf(complete: false));
    await goNutrition(tester);
    await capture(tester, '12-nutrition-profil');
  });

  testWidgets('réglages + thème sombre', (tester) async {
    await pumpApp(tester);
    await goHomeButton(tester, 'Réglages');
    await capture(tester, '13-reglages');

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();
    await capture(tester, '14-reglages-sombre');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await capture(tester, '15-accueil-sombre');
  });

  testWidgets('nutrition en thème sombre OLED', (tester) async {
    SharedPreferences.setMockInitialValues({'apparence.theme': 'oled'});
    await pumpApp(tester);
    await goNutrition(tester);
    await capture(tester, '16-nutrition-oled');
  });

  testWidgets('paywall exercice premium', (tester) async {
    final gated = _PremiumGated([summary('id-1', 'Balancier kettlebell')]);
    await pumpApp(tester, exercises: gated);
    await goHomeButton(tester, 'Bibliothèque d’exercices');
    await tester.tap(find.text('Balancier kettlebell'));
    await tester.pumpAndSettle();
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
