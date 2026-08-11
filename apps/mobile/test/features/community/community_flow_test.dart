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

import '../../support/fake_auth_repository.dart';
import '../../support/fake_community_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/navigation.dart';

/// L'écran Communauté sur le dépôt de DÉMONSTRATION : c'est le seul qui a des
/// données tant que le serveur communautaire n'existe pas, et donc le seul
/// endroit où les ACTIONS (rejoindre un défi, encourager) s'exercent vraiment.
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

/// L'application CONNECTÉE (hors démo), avec un dépôt communauté pilotable :
/// c'est elle qui doit distinguer erreur, chargement et vide.
Widget appWith(FakeCommunityRepository community) => ProviderScope(
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
        communityRepositoryProvider.overrideWithValue(community),
      ],
      child: const CarlysApp(),
    );

Future<void> reveal(WidgetTester tester, Finder item) async {
  final scrollable = find.byType(Scrollable).last;
  await tester.scrollUntilVisible(item, 240, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    seedCompletedFirstRun();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('fil, amis et défis servis en mémoire — privé compris',
      (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();
    await tapTab(tester, 'Communauté');

    // Le fil et les amis (AppSectionLabel rend ses titres en MAJUSCULES).
    expect(find.text('ENCOURAGEMENTS'), findsOneWidget);
    expect(find.textContaining('Belle série de 6 jours'), findsOneWidget);
    await reveal(tester, find.text('Tom'));
    // Tom ne partage pas sa progression : rien d'autre que son nom.
    expect(find.text('Profil privé'), findsOneWidget);

    // Les défis, sportifs et culturels.
    await reveal(tester, find.text('Qui connaît le mieux le haut du corps ?'));
    expect(find.text('CULTUREL'), findsOneWidget);
  });

  testWidgets('rejoindre un défi : participants +1 et bouton inversé',
      (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();
    await tapTab(tester, 'Communauté');

    // Le défi culturel n'est pas rejoint : sa carte propose « Participer ».
    await reveal(tester, find.text('Qui connaît le mieux le haut du corps ?'));
    expect(find.text('23 participants'), findsOneWidget);

    await tester.tap(find.text('Participer').first);
    await tester.pumpAndSettle();

    // L'écriture est passée ET la lecture s'est rafraîchie.
    expect(find.text('24 participants'), findsOneWidget);
    expect(find.text('23 participants'), findsNothing);
  });

  testWidgets('sans serveur : l’état vide, jamais un mensonge d’erreur',
      (tester) async {
    // Le dépôt « non branché » rend des listes vides : l'écran doit le dire
    // honnêtement (bientôt du monde), pas montrer une erreur.
    await tester.pumpWidget(appWith(FakeCommunityRepository()));
    await tester.pumpAndSettle();
    await tapTab(tester, 'Communauté');

    expect(find.text('Bientôt du monde ici'), findsOneWidget);
  });

  testWidgets('serveur en panne : état d’erreur, et « Réessayer » réessaie',
      (tester) async {
    final community = FakeCommunityRepository(failReads: true);
    await tester.pumpWidget(appWith(community));
    await tester.pumpAndSettle();
    await tapTab(tester, 'Communauté');

    // Une panne n'est PAS « bientôt du monde ici ».
    expect(find.text('Communauté indisponible'), findsOneWidget);
    expect(find.text('Bientôt du monde ici'), findsNothing);

    // Le serveur revient : « Réessayer » recharge vraiment.
    community.failReads = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('Communauté indisponible'), findsNothing);
    expect(find.text('Bientôt du monde ici'), findsOneWidget);
  });

  testWidgets('encourager un ami fait revenir un merci dans le fil',
      (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();
    await tapTab(tester, 'Communauté');

    await reveal(tester, find.byTooltip('Encourager').first);
    await tester.tap(find.byTooltip('Encourager').first);
    await tester.pumpAndSettle();

    // Le fil (en tête d'écran) gagne le remerciement.
    final scrollable = find.byType(Scrollable).last;
    await tester.drag(scrollable, const Offset(0, 2000), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Merci pour ton message'), findsOneWidget);
  });
}
