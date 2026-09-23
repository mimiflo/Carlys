import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_app.dart';
import '../../support/fake_community_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/navigation.dart';

/// L'écran Communauté sur le dépôt de DÉMONSTRATION (données embarquées,
/// actions en mémoire) puis sur un dépôt piloté : états, demandes d'ami,
/// défis, encouragements et confidentialité. Le harnais (`sampleWorldApp`,
/// `appWith`, `showCommunityTab`, `reveal`) vit dans
/// `support/community_app.dart`.
///
/// Depuis la refonte de septembre 2026, la page se range en trois onglets :
/// Défis (ouvert le premier), Ligue et Amis. Chaque test ouvre celui qui
/// porte ce qu'il vérifie.
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
    await openCommunity(tester, sampleWorldApp(), tab: 'Amis');

    // Le fil et les amis (AppSectionLabel rend ses titres en MAJUSCULES).
    expect(find.text('ENCOURAGEMENTS'), findsOneWidget);
    expect(find.textContaining('Belle série de 6 jours'), findsOneWidget);
    await reveal(tester, find.text('Tom'));
    // Tom ne partage pas sa progression : rien d'autre que son nom.
    expect(find.text('Profil privé'), findsOneWidget);

    // Les défis, sportifs et culturels, dans leur onglet.
    await showCommunityTab(tester, 'Défis');
    await reveal(tester, find.text('Qui connaît le mieux le haut du corps ?'));
    expect(find.text('CULTUREL'), findsOneWidget);
  });

  testWidgets('rejoindre un défi : participants +1 et bouton inversé', (
    tester,
  ) async {
    await tester.pumpWidget(sampleWorldApp());
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
    await openCommunity(
      tester,
      appWith(FakeCommunityRepository()),
      tab: 'Amis',
    );

    expect(find.text('Personne ici pour l’instant'), findsOneWidget);
    expect(find.text('Ajouter un ami'), findsWidgets);
    // Et le réglage de partage reste à portée : un compte neuf décide AVANT
    // son premier ami de ce qu'il montrera.
    await reveal(tester, find.text('CONFIDENTIALITÉ'));
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('défis du mois là, pas encore d’ami : les défis s’ouvrent, '
      'l’invitation vit dans l’onglet Amis', (tester) async {
    // Le serveur crée les défis du mois à la lecture : un compte neuf voit
    // des défis, jamais un écran vide. L'onglet Défis, ouvert le premier,
    // les montre ; et le geste qui débloque tout (ajouter un ami) vit dans
    // l'onglet Amis.
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
    expect(find.text('DÉFIS DU MOIS'), findsOneWidget);
    expect(find.text('21 jours de constance'), findsOneWidget);

    await showCommunityTab(tester, 'Amis');
    expect(find.text('Personne ici pour l’instant'), findsOneWidget);

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
    await openCommunity(tester, appWith(community), tab: 'Amis');

    expect(find.text('DEMANDES REÇUES'), findsOneWidget);
    expect(find.text('Pas encore d’ami'), findsNothing);
    expect(find.text('AMIS'), findsNothing);
  });

  testWidgets('serveur en panne : état d’erreur, et « Réessayer » réessaie', (
    tester,
  ) async {
    final community = FakeCommunityRepository(failReads: true);
    await openCommunity(tester, appWith(community));

    // Chaque onglet tranche sur SES sources, et nomme ce qui manque.
    expect(find.text('Défis indisponibles'), findsOneWidget);
    await showCommunityTab(tester, 'Amis');

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
    await openCommunity(tester, appWith(community), tab: 'Amis');

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
    await openCommunity(tester, appWith(community), tab: 'Amis');

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
    await openCommunity(tester, appWith(community));

    // Le bouton de l'en-tête, présent sur chaque onglet.
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
    await openCommunity(tester, appWith(community), tab: 'Amis');

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

  testWidgets('tirer pour rafraîchir fait apparaître une demande reçue', (
    tester,
  ) async {
    // Les demandes d'ami arrivent des AUTRES : rien sur l'appareil ne
    // déclenche leur relecture, et l'onglet vit dans un `IndexedStack` —
    // il reste monté, donc `autoDispose` ne se déclenche jamais. Sans geste
    // de rafraîchissement, la demande n'apparaissait qu'après avoir tué
    // l'application.
    final community = FakeCommunityRepository(
      friends: [
        const CommunityFriend(
          id: 'ami-1',
          displayName: 'Tom',
          streakDays: null,
          weeklySessions: null,
          sharesProgress: false,
        ),
      ],
    );
    await openCommunity(tester, appWith(community), tab: 'Amis');
    expect(find.text('Nina'), findsNothing);

    community.receiveRequest(
      FriendRequest(
        id: 'demande-nina',
        fromDisplayName: 'Nina',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    await tester.fling(find.byType(Scrollable).last, const Offset(0, 400), 800);
    await tester.pumpAndSettle();

    expect(find.text('Nina'), findsOneWidget);
  });

  testWidgets('encourager un ami DIT que le message est parti', (tester) async {
    // Le geste ne laissait aucune trace : le fil ne montre que les mots
    // reçus, la carte ne bouge pas, et rien ne confirmait le départ. Le
    // bouton semblait n'avoir rien fait.
    await openCommunity(tester, sampleWorldApp(), tab: 'Amis');

    await reveal(tester, find.byTooltip('Encourager').first);
    await tester.tap(find.byTooltip('Encourager').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Ton encouragement est parti à'),
      findsOneWidget,
    );
  });
}
