import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/demo/demo_overrides.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/carlys_profile/data/repositories/carlys_profile_repository_impl.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_carlys_profile_repository.dart';
import '../../support/fake_community_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/navigation.dart';

/// Les 4 profils Carlys : des identités, pas des niveaux — on les découvre
/// depuis le profil, on lit leur fiche, on choisit, on change d'avis.
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

Widget appWith(FakeCarlysProfileRepository repository) => ProviderScope(
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
        communityRepositoryProvider
            .overrideWithValue(FakeCommunityRepository()),
        syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
        appRestoreProvider.overrideWithValue(NoopAppRestore()),
        carlysProfileRepositoryProvider.overrideWithValue(repository),
      ],
      child: const CarlysApp(),
    );

Future<void> openCarlysProfiles(WidgetTester tester) async {
  await openProfile(tester);
  final row = find.text('Mon profil');
  final scrollable = find.byType(Scrollable).last;
  await tester.scrollUntilVisible(row, 240, scrollable: scrollable);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    seedCompletedFirstRun();
    // Fige les scènes animées (cœur battant) : sans quoi `pumpAndSettle`
    // ne se stabilise jamais.
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('les 4 identités s’affichent, le profil ACTUEL est marqué',
      (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();
    await openCarlysProfiles(tester);

    expect(find.text('LE CONSTRUCTEUR'), findsOneWidget);
    expect(find.text('LE CHALLENGER'), findsOneWidget);
    expect(find.text('L’ATHLÈTE'), findsOneWidget);
    expect(find.text('LE STRATÈGE'), findsOneWidget);

    // Le visiteur de démonstration est Challenger : un seul badge.
    expect(find.text('Ton profil'), findsOneWidget);
  });

  testWidgets('la fiche montre la devise et les publics, puis on choisit',
      (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();
    await openCarlysProfiles(tester);

    // La carte du Stratège est la dernière : elle se mérite en défilant.
    await tester.scrollUntilVisible(
      find.text('LE STRATÈGE'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('LE STRATÈGE'));
    await tester.pumpAndSettle();

    expect(find.text('« Je veux comprendre avant d’agir. »'), findsOneWidget);
    expect(find.text('Planifier avant d’agir.'), findsOneWidget);

    await tester.tap(find.text('Choisir ce profil'));
    await tester.pumpAndSettle();

    // Le badge a suivi : le Stratège est désormais le profil actuel…
    final strategeCard = find.ancestor(
      of: find.text('LE STRATÈGE'),
      matching: find.byType(Semantics),
    );
    expect(
      find.descendant(
        of: strategeCard.first,
        matching: find.text('Ton profil'),
      ),
      findsOneWidget,
    );
    // …et il n'y en a toujours qu'un.
    expect(find.text('Ton profil'), findsOneWidget);

    // Sa fiche le dit, et ne propose plus de le choisir.
    await tester.tap(find.text('LE STRATÈGE'));
    await tester.pumpAndSettle();
    expect(find.text('C’est ton profil actuel'), findsOneWidget);
    expect(find.text('Choisir ce profil'), findsNothing);
  });

  testWidgets('hors ligne : le choix échoue VISIBLEMENT, rien ne change',
      (tester) async {
    final repository = FakeCarlysProfileRepository(failChoose: true);
    await tester.pumpWidget(appWith(repository));
    await tester.pumpAndSettle();
    await openCarlysProfiles(tester);

    // Aucun profil choisi sur ce compte : pas de badge.
    expect(find.text('Ton profil'), findsNothing);

    await tester.tap(find.text('LE CONSTRUCTEUR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir ce profil'));
    await tester.pumpAndSettle();

    // L'échec s'affiche (SnackBar), le badge n'apparaît pas.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Ton profil'), findsNothing);
  });

  testWidgets('le profil choisi remonte jusqu’à la ligne du profil',
      (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();
    await openProfile(tester);

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
