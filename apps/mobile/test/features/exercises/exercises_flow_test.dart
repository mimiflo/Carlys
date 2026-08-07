import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/exercise_card.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_exercises_repository.dart';
import '../../support/fake_workout_repository.dart';

void main() {
  testWidgets(
      'parcours : accueil → bibliothèque → recherche → fiche d’exercice',
      (tester) async {
    final exercises = FakeExercisesRepository(
      [
        summary('id-1', 'Pompes', group: 'pectoraux'),
        summary('id-2', 'Squat', group: 'quadriceps'),
      ],
      pageSize: 10,
    );

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
          exercisesRepositoryProvider.overrideWithValue(exercises),
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Accueil authentifié → bibliothèque.
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text('Exercices'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pompes'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);

    // Recherche débouncée.
    await tester.enterText(find.byType(TextField), 'Squat');
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('Pompes'), findsNothing);
    // « Squat » vit aussi dans le champ de recherche : cibler la carte.
    final squatCard = find.widgetWithText(ExerciseCard, 'Squat');
    expect(squatCard, findsOneWidget);

    // Fiche détaillée.
    await tester.tap(squatCard);
    await tester.pumpAndSettle();

    expect(find.text('Description de Squat'), findsOneWidget);
    expect(find.text('Première étape'), findsOneWidget);
    expect(find.text('Muscles travaillés'), findsOneWidget);
  });

  testWidgets('bibliothèque vide : état dédié avec message', (tester) async {
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
          exercisesRepositoryProvider
              .overrideWithValue(FakeExercisesRepository(const [])),
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text('Exercices'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun exercice trouvé'), findsOneWidget);
  });
}
