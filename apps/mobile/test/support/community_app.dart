/// L'application montée pour les tests de la COMMUNAUTÉ : sur le dépôt de
/// démonstration (données embarquées, actions en mémoire) ou sur un dépôt
/// piloté, celui qui doit distinguer erreur, chargement et vide.
///
/// Le harnais est encodé UNE fois : si l'écran change d'onglet ou de
/// dépendances, c'est ici que ça change.
library;

import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/demo/demo_overrides.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'fake_community_repository.dart';
import 'fake_workout_repository.dart';
import 'navigation.dart';

/// L'écran Communauté sur le dépôt de DÉMONSTRATION.
Widget demoApp() => ProviderScope(
  overrides: [
    appEnvironmentProvider.overrideWithValue(
      const AppEnvironment(
        flavor: AppFlavor.demo,
        apiBaseUrl: 'http://localhost:3000',
      ),
    ),
    ...demoOverrides(),
    workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
  ],
  child: const CarlysApp(),
);

/// L'application CONNECTÉE (hors démo), avec un dépôt communauté pilotable.
Widget appWith(FakeCommunityRepository community) => ProviderScope(
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
    communityRepositoryProvider.overrideWithValue(community),
  ],
  child: const CarlysApp(),
);

/// Monte l'application et ouvre l'onglet Communauté.
Future<void> openCommunity(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await tapTab(tester, 'Communauté');
}

/// Fait défiler l'écran courant jusqu'à rendre [item] visible.
Future<void> reveal(WidgetTester tester, Finder item) async {
  final scrollable = find.byType(Scrollable).last;
  await tester.scrollUntilVisible(item, 240, scrollable: scrollable);
  await tester.pumpAndSettle();
}

/// Le menu « plus d'options » de la carte d'AMI de [name].
Finder optionsOf(String name) => find.byTooltip('Options pour $name');

/// Le menu « plus d'options » du MESSAGE reçu de [name].
Finder messageOptionsOf(String name) =>
    find.byTooltip('Options du message de $name');

/// Ouvre le [menu] (après l'avoir rendu visible) et choisit l'entrée [label].
Future<void> chooseOption(
  WidgetTester tester,
  Finder menu,
  String label,
) async {
  await reveal(tester, menu);
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}
