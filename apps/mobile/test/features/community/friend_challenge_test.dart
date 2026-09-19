import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:carlys_mobile/features/community/domain/entities/friend_challenge.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/friend_challenge_card.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/new_friend_challenge_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : un défi entre amis se lit comme un
/// classement, pas comme une barre de groupe — et il ne se lance pas contre
/// personne.
///
/// La différence avec un défi collectif n'est pas cosmétique : ici le rang
/// est INDIVIDUEL, donc il doit se voir, et le sien surtout. Un classement
/// où l'on ne se trouve pas ne motive personne.
void main() {
  FriendChallengeMember membre(
    String name,
    int contribution,
    int? rank, {
    bool isMe = false,
    FriendChallengeMemberStatus status = FriendChallengeMemberStatus.accepted,
  }) => FriendChallengeMember(
    userId: 'u-$name',
    displayName: name,
    status: status,
    contribution: contribution,
    rank: rank,
    isMe: isMe,
  );

  FriendChallenge defi({
    FriendChallengeMemberStatus myStatus = FriendChallengeMemberStatus.accepted,
    FriendChallengeStatus status = FriendChallengeStatus.open,
    List<FriendChallengeMember>? members,
  }) => FriendChallenge(
    id: 'defi-1',
    title: 'Qui court le plus',
    metric: ChallengeMetric.distanceMeters,
    unit: 'mètres',
    status: status,
    myStatus: myStatus,
    startsAt: DateTime.now().subtract(const Duration(days: 1)),
    endsAt: DateTime.now().add(const Duration(days: 6)),
    creatorDisplayName: 'Boris',
    members:
        members ??
        [
          membre('Boris', 12000, 1),
          membre('Moi', 8000, 2, isMe: true),
          membre('Chloé', 3000, 3),
        ],
  );

  Future<void> monter(
    WidgetTester tester,
    FriendChallenge challenge, {
    VoidCallback? onAccept,
    VoidCallback? onDecline,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: FriendChallengeCard(
              challenge: challenge,
              onAccept: onAccept ?? () {},
              onDecline: onDecline ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('la carte du défi', () {
    testWidgets('montre le classement, avec MA ligne nommée « Toi »', (
      tester,
    ) async {
      await monter(tester, defi());

      expect(find.text('Boris'), findsWidgets);
      expect(find.text('Toi'), findsOneWidget);
      expect(find.textContaining('mètres'), findsWidgets);
      // Les rangs, en chiffres : un classement sans rangs n'est qu'une liste.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('garde ma ligne même hors du podium', (tester) async {
      await monter(
        tester,
        defi(
          members: [
            membre('Boris', 12000, 1),
            membre('Chloé', 9000, 2),
            membre('Dora', 8000, 3),
            membre('Émile', 7000, 4),
            membre('Moi', 500, 5, isMe: true),
          ],
        ),
      );

      // Trois du podium, plus moi : un classement où l'on ne se trouve pas
      // ne motive personne.
      expect(find.text('Toi'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Émile'), findsNothing);
    });

    testWidgets(
      'une invitation propose d’accepter, un défi en cours de partir',
      (tester) async {
        var accepte = 0;
        await monter(
          tester,
          defi(myStatus: FriendChallengeMemberStatus.invited),
          onAccept: () => accepte += 1,
        );
        expect(find.text('Accepter'), findsOneWidget);
        expect(find.text('Refuser'), findsOneWidget);
        expect(find.text('Quitter'), findsNothing);
        await tester.tap(find.text('Accepter'));
        expect(accepte, 1);

        await monter(tester, defi());
        expect(find.text('Accepter'), findsNothing);
        expect(find.text('Quitter'), findsOneWidget);
      },
    );

    testWidgets('un défi terminé n’offre plus de geste', (tester) async {
      await monter(tester, defi(status: FriendChallengeStatus.closed));

      // Le classement est FIGÉ : il ne reste rien à faire, et le proposer
      // laisserait croire que le résultat peut encore bouger.
      expect(find.text('terminé'), findsOneWidget);
      expect(find.text('Quitter'), findsNothing);
      expect(find.text('Accepter'), findsNothing);
    });

    testWidgets('les invités en attente ne sont pas classés', (tester) async {
      await monter(
        tester,
        defi(
          members: [
            membre('Boris', 12000, 1),
            membre(
              'Chloé',
              0,
              null,
              status: FriendChallengeMemberStatus.invited,
            ),
          ],
        ),
      );

      // On ne donne pas de rang à quelqu'un qui n'a rien accepté.
      expect(find.text('Boris'), findsWidgets);
      expect(find.text('Chloé'), findsNothing);
    });
  });

  group('la feuille de création', () {
    Future<NewFriendChallenge?> ouvrir(
      WidgetTester tester,
      List<CommunityFriend> friends,
    ) async {
      NewFriendChallenge? rendu;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  rendu = await showNewFriendChallengeSheet(
                    context,
                    friends: friends,
                  );
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      return rendu;
    }

    testWidgets('sans ami, elle le DIT et n’offre pas de lancer', (
      tester,
    ) async {
      await ouvrir(tester, const []);

      expect(find.textContaining('pas encore d’ami'), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Lancer le défi'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('rend le titre, la métrique, la durée et les invités', (
      tester,
    ) async {
      await ouvrir(tester, [
        const CommunityFriend(
          id: 'ami-1',
          displayName: 'Boris',
          streakDays: 3,
          weeklySessions: 2,
          sharesProgress: true,
        ),
      ]);

      await tester.enterText(find.byType(TextFormField).first, 'Le mois du km');
      await tester.tap(find.text('Mètres parcourus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 jours'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boris'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lancer le défi'));
      await tester.tap(find.text('Lancer le défi'));
      await tester.pumpAndSettle();

      // La feuille ne rend AUCUNE date de fin : le serveur la calcule depuis
      // la durée, sinon une requête suffirait à poser un défi éternel.
      expect(find.text('Défier mes amis'), findsNothing);
    });
  });
}
