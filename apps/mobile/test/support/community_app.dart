/// L'application montée pour les tests de la COMMUNAUTÉ : sur le dépôt en
/// mémoire (monde d'exemple, actions fonctionnelles) ou sur un dépôt piloté,
/// celui qui doit distinguer erreur, chargement et vide.
///
/// Le harnais est encodé UNE fois : si l'écran change d'onglet ou de
/// dépendances, c'est ici que ça change.
library;

import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:carlys_mobile/features/nutrition/presentation/controllers/water_controllers.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'fake_community_repository.dart';
import 'fake_water_store.dart';
import 'fake_workout_repository.dart';
import 'in_memory_community_repository.dart';
import 'navigation.dart';

/// L'écran Communauté sur le MONDE D'EXEMPLE en mémoire (amis, défis,
/// encouragements — actions fonctionnelles, aucun réseau). [community] le
/// fournit quand le test doit lire ce que le dépôt a reçu.
Widget sampleWorldApp({InMemoryCommunityRepository? community}) =>
    ProviderScope(
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
        waterStoreProvider.overrideWithValue(FakeWaterStore()),
        syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
        appRestoreProvider.overrideWithValue(NoopAppRestore()),
        communityRepositoryProvider.overrideWithValue(
          community ?? InMemoryCommunityRepository(),
        ),
      ],
      child: const CarlysApp(),
    );

/// L'application connectée sur un dépôt communauté PILOTABLE (erreur, vide…).
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
    waterStoreProvider.overrideWithValue(FakeWaterStore()),
    syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
    appRestoreProvider.overrideWithValue(NoopAppRestore()),
    communityRepositoryProvider.overrideWithValue(community),
  ],
  child: const CarlysApp(),
);

/// Monte l'application et ouvre l'onglet Communauté — sur son onglet
/// [tab] (« Défis », « Ligue » ou « Amis ») quand il est donné, sinon sur
/// celui qui s'ouvre le premier.
Future<void> openCommunity(
  WidgetTester tester,
  Widget app, {
  String? tab,
}) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await tapTab(tester, 'Communauté');
  if (tab != null) {
    await showCommunityTab(tester, tab);
  }
}

/// Ouvre l'onglet [label] de la Communauté, sur sa piste segmentée : le
/// même mot peut vivre ailleurs dans la page (« Amis » est aussi une
/// section), seule la piste fait foi.
///
/// La piste défile avec la page : on remonte d'abord en haut, comme on le
/// ferait du pouce — en-tête et loupe compris, que le test suivant peut
/// vouloir toucher.
Future<void> showCommunityTab(WidgetTester tester, String label) async {
  final page = find
      .descendant(
        of: find.byType(CommunityScreen),
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(page).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AppSegmentedTabs),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
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
