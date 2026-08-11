import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/demo/demo_overrides.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_community_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/navigation.dart';

/// L'écran Communauté sur le dépôt de DÉMONSTRATION (données embarquées,
/// actions en mémoire) puis sur un dépôt piloté : états, demandes d'ami,
/// défis, encouragements et confidentialité.
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

  testWidgets('compte neuf : l’état vide invite à ajouter un premier ami',
      (tester) async {
    // Toutes les listes vides : l'écran doit le dire honnêtement — et donner
    // le geste qui débloque tout (ajouter un ami), pas montrer une erreur.
    await tester.pumpWidget(appWith(FakeCommunityRepository()));
    await tester.pumpAndSettle();
    await tapTab(tester, 'Communauté');

    expect(find.text('Personne ici pour l’instant'), findsOneWidget);
    expect(find.text('Ajouter un ami'), findsWidgets);
  });

  testWidgets('serveur en panne : état d’erreur, et « Réessayer » réessaie',
      (tester) async {
    final community = FakeCommunityRepository(failReads: true);
    await tester.pumpWidget(appWith(community));
    await tester.pumpAndSettle();
    await tapTab(tester, 'Communauté');

    // Une panne n'est PAS « personne ici ».
    expect(find.text('Communauté indisponible'), findsOneWidget);
    expect(find.text('Personne ici pour l’instant'), findsNothing);

    // Le serveur revient : « Réessayer » recharge vraiment.
    community.failReads = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('Communauté indisponible'), findsNothing);
    expect(find.text('Personne ici pour l’instant'), findsOneWidget);
  });

  testWidgets('accepter une demande : elle disparaît, l’ami apparaît',
      (tester) async {
    final community = FakeCommunityRepository(
      requests: [
        FriendRequest(
          id: 'demande-nina',
          fromDisplayName: 'Nina',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    );
    await tester.pumpWidget(appWith(community));
    await tester.pumpAndSettle();
    await tapTab(tester, 'Communauté');

    expect(find.text('DEMANDES REÇUES'), findsOneWidget);
    expect(find.text('Nina'), findsOneWidget);

    await tester.tap(find.byTooltip('Accepter'));
    await tester.pumpAndSettle();

    expect(find.text('DEMANDES REÇUES'), findsNothing);
    // Nina est désormais dans la section AMIS.
    expect(find.text('AMIS'), findsOneWidget);
    expect(find.text('Nina'), findsOneWidget);
  });

  testWidgets('ajouter un ami : la confirmation reste opaque', (tester) async {
    final community = FakeCommunityRepository();
    await tester.pumpWidget(appWith(community));
    await tester.pumpAndSettle();
    await tapTab(tester, 'Communauté');

    await tester.tap(find.byTooltip('Ajouter un ami'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'amie@carlys.test');
    await tester.pump();
    await tester.ensureVisible(find.text('Envoyer la demande'));
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();

    expect(community.sentRequests, ['amie@carlys.test']);
    // Jamais « demande envoyée à X » : on ne confirme pas qu'un compte existe.
    expect(
      find.text('Si ce compte existe, il recevra ta demande.'),
      findsOneWidget,
    );
  });

  testWidgets('le réglage de partage écrit bien la préférence', (tester) async {
    final community = FakeCommunityRepository(
      friends: const [
        CommunityFriend(
          id: 'amie-1',
          displayName: 'Sarah',
          streakDays: 3,
          weeklySessions: 2,
          sharesProgress: true,
        ),
      ],
    );
    await tester.pumpWidget(appWith(community));
    await tester.pumpAndSettle();
    await tapTab(tester, 'Communauté');

    final scrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.byType(Switch),
      240,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(community.shares, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
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
