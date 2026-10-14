import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/carlys_profile/data/repositories/carlys_profile_repository_impl.dart';
import 'package:carlys_mobile/features/carlys_profile/presentation/widgets/carlys_profile_card.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/presentation/providers/water_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_carlys_profile_repository.dart';
import '../../support/fake_community_repository.dart';
import '../../support/fake_water_store.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/in_memory_account_repositories.dart';
import '../../support/local_data_overrides.dart';
import '../../support/navigation.dart';

/// Les 4 profils Carlys : des identités, pas des niveaux — on les découvre
/// depuis le profil, on lit leur fiche, on choisit, on change d'avis.
/// L'application sur les dépôts de compte EN MÉMOIRE : le choix de profil
/// est réellement écrit chez le dépôt d'auth, `me()` le reflète — le flux de
/// production, sans réseau.
Widget worldApp() {
  final auth = InMemoryAuthRepository();
  return ProviderScope(
    overrides: [
      appEnvironmentProvider.overrideWithValue(
        const AppEnvironment(
          flavor: AppFlavor.development,
          apiBaseUrl: 'http://localhost:3000',
        ),
      ),
      authRepositoryProvider.overrideWithValue(auth),
      carlysProfileRepositoryProvider.overrideWithValue(
        InMemoryCarlysProfileRepository(auth),
      ),
      ...localDataOverrides(),
      communityRepositoryProvider.overrideWithValue(FakeCommunityRepository()),
      waterStoreProvider.overrideWithValue(FakeWaterStore()),
      syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
      appRestoreProvider.overrideWithValue(NoopAppRestore()),
    ],
    child: const CarlysApp(),
  );
}

Widget appWith(FakeCarlysProfileRepository repository) => ProviderScope(
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
    ...localDataOverrides(),
    communityRepositoryProvider.overrideWithValue(FakeCommunityRepository()),
    waterStoreProvider.overrideWithValue(FakeWaterStore()),
    syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
    appRestoreProvider.overrideWithValue(NoopAppRestore()),
    carlysProfileRepositoryProvider.overrideWithValue(repository),
  ],
  child: const CarlysApp(),
);

Future<void> openCarlysProfiles(WidgetTester tester) async {
  await openProfileSettings(tester);
  final row = find.text('Mon profil');
  final scrollable = find.byType(Scrollable).last;
  await tester.scrollUntilVisible(row, 240, scrollable: scrollable);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

/// L'anneau au segment voyageur — la marque du profil ACTUEL.
/// La carte du profil retenu (liseré violet plein, coche, « Ton profil »).
final Finder selectedCard = find.byWidgetPredicate(
  (widget) => widget is CarlysProfileCard && widget.isCurrent,
);

void main() {
  setUp(() {
    seedCompletedFirstRun();
    // Fige les scènes animées (cœur battant) : sans quoi `pumpAndSettle`
    // ne se stabilise jamais.
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('les 4 identités s’affichent, le profil ACTUEL est marqué', (
    tester,
  ) async {
    await tester.pumpWidget(worldApp());
    await tester.pumpAndSettle();
    await openCarlysProfiles(tester);

    expect(find.text('Le Constructeur'), findsOneWidget);
    expect(find.text('Le Challenger'), findsOneWidget);
    expect(find.text('L’Athlète'), findsOneWidget);
    expect(find.text('Le Stratège'), findsOneWidget);

    // Le visiteur de démonstration est Challenger : un seul badge, sur SA
    // carte.
    expect(find.text('Ton profil'), findsOneWidget);
    expect(selectedCard, findsOneWidget);
    expect(
      find.descendant(of: selectedCard, matching: find.text('Le Challenger')),
      findsOneWidget,
    );
  });

  testWidgets('la fiche montre la devise et les publics, puis on choisit', (
    tester,
  ) async {
    await tester.pumpWidget(worldApp());
    await tester.pumpAndSettle();
    await openCarlysProfiles(tester);

    // La carte du Stratège est la dernière : elle se mérite en défilant.
    await tester.scrollUntilVisible(
      find.text('Le Stratège'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Le Stratège'));
    await tester.pumpAndSettle();

    expect(find.text('« Je veux comprendre avant d’agir. »'), findsOneWidget);
    expect(find.text('Planifier avant d’agir.'), findsOneWidget);

    // La fiche est haute : son bouton se mérite en défilant.
    await tester.ensureVisible(find.text('Choisir ce profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir ce profil'));
    await tester.pumpAndSettle();

    // Le badge a suivi : le Stratège est désormais le profil actuel…
    final strategeCard = find.ancestor(
      of: find.text('Le Stratège'),
      matching: find.byType(CarlysProfileCard),
    );
    expect(
      find.descendant(of: strategeCard, matching: find.text('Ton profil')),
      findsOneWidget,
    );
    // …et il n'y en a toujours qu'un : la sélection a suivi.
    expect(find.text('Ton profil'), findsOneWidget);
    expect(selectedCard, findsOneWidget);
    expect(
      find.descendant(of: selectedCard, matching: find.text('Le Stratège')),
      findsOneWidget,
    );

    // Sa fiche le dit, et ne propose plus de le choisir.
    await tester.tap(find.text('Le Stratège'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('C’est ton profil actuel'));
    expect(find.text('C’est ton profil actuel'), findsOneWidget);
    expect(find.text('Choisir ce profil'), findsNothing);
  });

  testWidgets('hors ligne : le choix échoue VISIBLEMENT, rien ne change', (
    tester,
  ) async {
    final repository = FakeCarlysProfileRepository(failChoose: true);
    await tester.pumpWidget(appWith(repository));
    await tester.pumpAndSettle();
    await openCarlysProfiles(tester);

    // Aucun profil choisi sur ce compte : pas de badge.
    expect(find.text('Ton profil'), findsNothing);

    await tester.tap(find.text('Le Constructeur'));
    await tester.pumpAndSettle();
    // La fiche est haute : son bouton se mérite en défilant.
    await tester.ensureVisible(find.text('Choisir ce profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir ce profil'));
    await tester.pumpAndSettle();

    // L'échec s'affiche (popup au ton « erreur », le message du dépôt), le
    // badge n'apparaît pas.
    expect(
      find.widgetWithText(AppPopupCard, 'hors ligne (voulu par le test)'),
      findsOneWidget,
    );
    expect(find.text('Ton profil'), findsNothing);
  });

  testWidgets('le profil choisi remonte jusqu’à la ligne du profil', (
    tester,
  ) async {
    await tester.pumpWidget(worldApp());
    await tester.pumpAndSettle();
    await openProfileSettings(tester);

    // Le visiteur de démonstration est déjà Challenger.
    final scrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Le Challenger'),
      240,
      scrollable: scrollable,
    );
    expect(find.text('Le Challenger'), findsOneWidget);
  });
}
