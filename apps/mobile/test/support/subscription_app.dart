/// L'application montée pour les tests de l'ABONNEMENT, et le chemin qui
/// mène à son écran.
///
/// Le parcours est encodé UNE fois : si la bannière de plan change de place,
/// c'est ici qu'elle change.
library;

import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_plan_card.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/subscription/presentation/controllers/subscription_controllers.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'fake_exercises_repository.dart';
import 'fake_subscription_repository.dart';
import 'fake_workout_repository.dart';
import 'navigation.dart';

/// L'application complète, session ouverte, avec un abonnement factice.
///
/// [opened] reçoit les adresses que l'écran demande d'ouvrir : un test ne
/// lance jamais de navigateur.
Widget appWith({
  required FakeSubscriptionRepository subscription,
  FakeExercisesRepository? exercises,
  List<Uri>? opened,
}) => ProviderScope(
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
    subscriptionRepositoryProvider.overrideWithValue(subscription),
    if (exercises != null)
      exercisesRepositoryProvider.overrideWithValue(exercises),
    if (opened != null)
      urlOpenerProvider.overrideWithValue((url) async {
        opened.add(url);
        return true;
      }),
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

/// Ouvre l'écran d'abonnement comme l'utilisateur : le profil, puis sa
/// bannière de plan.
Future<void> openSubscription(WidgetTester tester) async {
  await openProfile(tester);
  await reveal(tester, find.byType(ProfilePlanCard));
  await tester.tap(find.byType(ProfilePlanCard));
  await tester.pumpAndSettle();
}
