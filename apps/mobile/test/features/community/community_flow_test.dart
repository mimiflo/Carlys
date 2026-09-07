import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_app.dart';
import '../../support/fake_community_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/navigation.dart';

/// L'écran Communauté sur le dépôt de DÉMONSTRATION (données embarquées,
/// actions en mémoire) puis sur un dépôt piloté : états, demandes d'ami,
/// défis, encouragements et confidentialité. Le harnais (`demoApp`,
/// `appWith`, `reveal`) vit dans `support/community_app.dart`.
void main() {
  setUp(() {
    seedCompletedFirstRun();
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

  testWidgets('fil, amis et défis servis en mémoire — privé compris', (
    tester,
  ) async {
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

  testWidgets('rejoindre un défi : participants +1 et bouton inversé', (
    tester,
  ) async {
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

  testWidgets('compte neuf : l’état vide invite à ajouter un premier ami', (
    tester,
  ) async {
    // Toutes les listes vides : l'écran doit le dire honnêtement — et donner
    // le geste qui débloque tout (ajouter un ami), pas montrer une erreur.
    await tester.pumpWidget(appWith(FakeCommunityRepository()));
    await tester.pumpAndSettle();
    await tapTab(tester, 'Communauté');

    expect(find.text('Personne ici pour l’instant'), findsOneWidget);
    expect(find.text('Ajouter un ami'), findsWidgets);
  });

  testWidgets('défis du mois là, pas encore d’ami : l’invitation vit dans '
      'la section Amis', (tester) async {
    // Le serveur crée les défis du mois à la lecture : un compte neuf voit
    // des défis, jamais un écran vide. « Personne ici » serait donc faux, et
    // le geste qui débloque tout (ajouter un ami) doit survivre à sa place.
    final community = FakeCommunityRepository(
      challenges: [
        CommunityChallenge(
          id: 'defi-constance',
          kind: ChallengeKind.sport,
          title: '21 jours de constance',
          description: 'Une activité par jour pendant trois semaines.',
          participants: 12,
          progress: 0.3,
          joined: false,
          endsAt: DateTime.now().add(const Duration(days: 10)),
        ),
      ],
    );
    await openCommunity(tester, appWith(community));

    expect(find.text('Personne ici pour l’instant'), findsNothing);
    expect(find.text('DÉFIS'), findsOneWidget);
    expect(find.text('21 jours de constance'), findsOneWidget);
    expect(find.text('AMIS'), findsOneWidget);
    expect(find.text('Pas encore d’ami'), findsOneWidget);

    // L'invitation mène bien à la feuille d'ajout.
    final invite = find.widgetWithText(FilledButton, 'Ajouter un ami');
    await tester.ensureVisible(invite);
    await tester.tap(invite);
    await tester.pumpAndSettle();
    expect(find.text('Envoyer la demande'), findsOneWidget);
  });

  testWidgets('une demande reçue suffit : plus d’invitation, la section '
      'Amis attend la réponse', (tester) async {
    final community = FakeCommunityRepository(
      requests: [
        FriendRequest(
          id: 'demande-nina',
          fromDisplayName: 'Nina',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    );
    await openCommunity(tester, appWith(community));

    expect(find.text('DEMANDES REÇUES'), findsOneWidget);
    expect(find.text('Pas encore d’ami'), findsNothing);
    expect(find.text('AMIS'), findsNothing);
  });

  testWidgets('serveur en panne : état d’erreur, et « Réessayer » réessaie', (
    tester,
  ) async {
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

  testWidgets('hors connexion : le statut le DIT, comme le coach', (
    tester,
  ) async {
    final community = FakeCommunityRepository(offline: true);
    await tester.pumpWidget(appWith(community));
    await tester.pumpAndSettle();
    await tapTab(tester, 'Communauté');

    // Pas « indisponible », pas « personne ici » : hors connexion.
    expect(find.text('Hors connexion'), findsOneWidget);
    expect(find.text('Communauté indisponible'), findsNothing);
    expect(find.text('Personne ici pour l’instant'), findsNothing);

    // Le réseau revient : « Réessayer » ranime l'écran.
    community.offline = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Hors connexion'), findsNothing);
    expect(find.text('Personne ici pour l’instant'), findsOneWidget);
  });

  testWidgets('accepter une demande : elle disparaît, l’ami apparaît', (
    tester,
  ) async {
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

  testWidgets('encourager un ami fait revenir un merci dans le fil', (
    tester,
  ) async {
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
