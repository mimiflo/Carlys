import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/muscle_group_card.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_plan_card.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_exercises_repository.dart';
import '../../support/fake_subscription_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';

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
        appRestoreProvider.overrideWithValue(NoopAppRestore()),
        subscriptionRepositoryProvider.overrideWithValue(subscription),
        if (exercises != null)
          exercisesRepositoryProvider.overrideWithValue(exercises),
      ],
      child: const CarlysApp(),
    );

/// Rend visible un élément de l'écran COURANT (dernier Scrollable de la
/// pile) : remonte d'abord en haut, puis descend jusqu'à la cible —
/// déterministe quelle que soit la position de défilement précédente.
Future<void> reveal(WidgetTester tester, Finder item) async {
  final scrollable = find.byType(Scrollable).last;
  await tester.drag(scrollable, const Offset(0, 2000), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(item, 150, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Parcours de première ouverture déjà terminé : l'abonnement s'ouvre
    // depuis le profil, avec sa croix de fermeture (le temps d'arrêt du
    // tunnel est couvert par first_run_journey_test.dart).
    seedCompletedFirstRun();
    // L'écran porte une scène 3D et une bordure animée en boucle :
    // animations réduites pour que pumpAndSettle converge.
    TestWidgetsFlutterBinding.ensureInitialized();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('plan gratuit : droits verrouillés affichés', (tester) async {
    await tester.pumpWidget(
      appWith(subscription: FakeSubscriptionRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text('Profil'),
      ),
    );
    await tester.pumpAndSettle();
    // L'abonnement s'ouvre depuis la bannière de plan du profil.
    await reveal(tester, find.byType(ProfilePlanCard));
    await tester.tap(find.byType(ProfilePlanCard));
    await tester.pumpAndSettle();

    // Accroche de la maquette 2i : label mono, titre display, croix de
    // fermeture — plus aucune barre de titre.
    expect(find.text('CARLYS PREMIUM'), findsOneWidget);
    expect(find.text('Ton coach\nne dort jamais.'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    expect(find.text('Programmes illimités'), findsOneWidget);
    expect(find.text('Statistiques avancées'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.text('GRATUIT'), findsOneWidget);
    expect(find.text('Aucun abonnement actif'), findsOneWidget);
  });

  testWidgets('plan premium : droits actifs et état de l’abonnement',
      (tester) async {
    await tester.pumpWidget(
      appWith(subscription: FakeSubscriptionRepository(isPremium: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text('Profil'),
      ),
    );
    await tester.pumpAndSettle();
    // L'abonnement s'ouvre depuis la bannière de plan du profil.
    await reveal(tester, find.byType(ProfilePlanCard));
    await tester.tap(find.byType(ProfilePlanCard));
    await tester.pumpAndSettle();

    expect(find.text('Premium'), findsWidgets);
    expect(find.text('ACTIF'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
    // Échéance formatée par formatShortDateMono (« DIM. 6 SEPT. » en UTC ;
    // le jour local dépend du fuseau de la machine de test).
    expect(find.textContaining('Renouvellement le '), findsOneWidget);
    expect(find.textContaining('SEPT.'), findsOneWidget);
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

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text('Exercices'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    // La bibliothèque s'ouvre sur la grille des groupes : on passe par
    // « Tous les mouvements » pour atteindre le catalogue. On vise la CARTE,
    // pas son libellé, qui passe sous la barre d'onglets en petite surface.
    await tester.tap(
      find.widgetWithText(MuscleGroupCard, 'Tous les mouvements'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balancier kettlebell'));
    await tester.pumpAndSettle();

    expect(find.text('Exercice Premium'), findsOneWidget);

    await tester.tap(find.text('Voir mon abonnement'));
    await tester.pumpAndSettle();

    expect(find.text('GRATUIT'), findsOneWidget);
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
