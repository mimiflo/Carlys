import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_exercises_repository.dart';
import '../../support/fake_subscription_repository.dart';
import '../../support/fake_workout_repository.dart';

Widget appWith({
  required FakeSubscriptionRepository subscription,
  FakeExercisesRepository? exercises,
}) =>
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
        syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
        subscriptionRepositoryProvider.overrideWithValue(subscription),
        if (exercises != null)
          exercisesRepositoryProvider.overrideWithValue(exercises),
      ],
      child: const CarlysApp(),
    );

void main() {
  testWidgets('plan gratuit : droits verrouillés affichés', (tester) async {
    await tester.pumpWidget(
      appWith(subscription: FakeSubscriptionRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abonnement'));
    await tester.pumpAndSettle();

    expect(find.text('Programmes illimités'), findsOneWidget);
    expect(find.text('Statistiques avancées'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('plan premium : droits actifs et état de l’abonnement',
      (tester) async {
    await tester.pumpWidget(
      appWith(subscription: FakeSubscriptionRepository(isPremium: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abonnement'));
    await tester.pumpAndSettle();

    expect(find.text('Premium'), findsWidgets);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
    expect(find.textContaining('renouvellement le'), findsOneWidget);
  });

  testWidgets(
      'exercice premium refusé par le serveur : invitation vers l’abonnement',
      (tester) async {
    final exercises = _PremiumGatedExercises([
      summary('id-1', 'Balancier kettlebell', group: 'dos'),
    ]);

    await tester.pumpWidget(
      appWith(
        subscription: FakeSubscriptionRepository(),
        exercises: exercises,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bibliothèque d’exercices'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balancier kettlebell'));
    await tester.pumpAndSettle();

    expect(find.text('Exercice Premium'), findsOneWidget);

    await tester.tap(find.text('Voir mon abonnement'));
    await tester.pumpAndSettle();

    expect(find.text('Vos droits'), findsOneWidget);
  });
}

/// Bibliothèque dont TOUTES les fiches sont refusées par le « serveur ».
class _PremiumGatedExercises extends FakeExercisesRepository {
  _PremiumGatedExercises(super.all) : super(pageSize: 10);

  @override
  Future<ExerciseDetail> byIdOrSlug(String idOrSlug) {
    return Future.error(
      const ForbiddenException('Exercice réservé aux membres Premium.'),
    );
  }
}
