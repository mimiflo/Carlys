import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:carlys_mobile/features/community/domain/entities/community_moderation.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/blocked_user_card.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/friend_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_app.dart';
import '../../support/fake_community_repository.dart';
import '../../support/first_run_prefs.dart';

/// Les gestes de protection de la communauté : retirer un ami, bloquer,
/// débloquer, signaler (une personne ou un mot), retirer un mot du fil. Le
/// dépôt factice reçoit l'appel, l'écran reflète l'état, l'échec hors ligne
/// se dit.
const _sarah = CommunityFriend(
  id: 'amie-sarah',
  displayName: 'Sarah',
  streakDays: 3,
  weeklySessions: 2,
  sharesProgress: true,
);

const _tom = CommunityFriend(
  id: 'ami-tom',
  displayName: 'Tom',
  streakDays: null,
  weeklySessions: null,
  sharesProgress: false,
);

Encouragement _wordFrom(CommunityFriend friend, String message) {
  return Encouragement(
    id: 'mot-${friend.id}',
    fromUserId: friend.id,
    fromName: friend.displayName,
    message: message,
    sentAt: DateTime.now().subtract(const Duration(hours: 1)),
  );
}

Finder _friendNamed(String name) =>
    find.descendant(of: find.byType(FriendCard), matching: find.text(name));

Finder _blockedNamed(String name) => find.descendant(
  of: find.byType(BlockedUserCard),
  matching: find.text(name),
);

Finder _confirm(String label) => find.widgetWithText(FilledButton, label);

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

  group('retirer un ami', () {
    testWidgets('confirmation, puis la carte disparaît et le dépôt sait', (
      tester,
    ) async {
      final community = FakeCommunityRepository(friends: [_sarah, _tom]);
      await openCommunity(tester, appWith(community));

      // Le menu est une vraie cible tactile, pas un ornement.
      await reveal(tester, optionsOf('Tom'));
      expect(
        tester.getSize(optionsOf('Tom')).shortestSide,
        greaterThanOrEqualTo(AppSpacing.touchTarget),
      );

      await chooseOption(tester, optionsOf('Tom'), 'Retirer');

      // Rien ne part sans confirmation : la feuille dit ce qui va se passer.
      expect(find.text('Retirer Tom de tes amis ?'), findsOneWidget);
      expect(community.removedFriends, isEmpty);

      await tester.tap(_confirm('Retirer'));
      await tester.pumpAndSettle();

      expect(community.removedFriends, ['ami-tom']);
      expect(_friendNamed('Tom'), findsNothing);
      expect(_friendNamed('Sarah'), findsOneWidget);
      expect(find.text('Tom ne fait plus partie de tes amis.'), findsOneWidget);
    });

    testWidgets('annuler ne touche à rien', (tester) async {
      final community = FakeCommunityRepository(friends: [_tom]);
      await openCommunity(tester, appWith(community));

      await chooseOption(tester, optionsOf('Tom'), 'Retirer');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(community.removedFriends, isEmpty);
      expect(_friendNamed('Tom'), findsOneWidget);
    });

    testWidgets('hors ligne : l’échec se dit, l’ami reste', (tester) async {
      final community = FakeCommunityRepository(friends: [_tom]);
      await openCommunity(tester, appWith(community));

      // Le réseau tombe APRÈS le chargement : le geste, lui, doit le dire.
      community.offline = true;
      await chooseOption(tester, optionsOf('Tom'), 'Retirer');
      await tester.tap(_confirm('Retirer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hors connexion'), findsOneWidget);
      expect(_friendNamed('Tom'), findsOneWidget);
    });
  });

  group('bloquer', () {
    testWidgets(
      'confirmation, puis la personne quitte les amis et le fil, sans un '
      'mot accusateur, et rejoint « Personnes bloquées »',
      (tester) async {
        final community = FakeCommunityRepository(
          friends: [_sarah, _tom],
          feed: [_wordFrom(_tom, 'Trop fort ce matin.')],
        );
        await openCommunity(tester, appWith(community));
        expect(find.text('Trop fort ce matin.'), findsOneWidget);

        await chooseOption(tester, optionsOf('Tom'), 'Bloquer');
        expect(find.text('Bloquer Tom ?'), findsOneWidget);
        expect(community.blockedIds, isEmpty);

        await tester.tap(_confirm('Bloquer'));
        await tester.pumpAndSettle();

        expect(community.blockedIds, ['ami-tom']);
        expect(_friendNamed('Tom'), findsNothing);
        expect(_friendNamed('Sarah'), findsOneWidget);
        expect(find.text('Trop fort ce matin.'), findsNothing);
        expect(find.textContaining('Tu ne verras plus Tom'), findsOneWidget);

        await reveal(tester, find.text('PERSONNES BLOQUÉES'));
        expect(_blockedNamed('Tom'), findsOneWidget);
      },
    );

    testWidgets(
      'depuis un MOT du fil : dernier recours quand l’auteur n’est plus '
      'un ami',
      (tester) async {
        // L'amitié a été rompue, le mot blessant est resté : sans le menu du
        // mot, plus aucun chemin ne mène à ce blocage.
        final community = FakeCommunityRepository(
          friends: [_sarah],
          feed: [
            _wordFrom(_tom, 'Tu n’y arriveras jamais.'),
            _wordFrom(_sarah, 'Belle série !'),
          ],
        );
        await openCommunity(tester, appWith(community));
        expect(_friendNamed('Tom'), findsNothing);

        await chooseOption(tester, messageOptionsOf('Tom'), 'Bloquer');
        expect(find.text('Bloquer Tom ?'), findsOneWidget);
        expect(community.blockedIds, isEmpty);

        await tester.tap(_confirm('Bloquer'));
        await tester.pumpAndSettle();

        expect(community.blockedIds, ['ami-tom']);
        expect(find.text('Tu n’y arriveras jamais.'), findsNothing);
        expect(find.text('Belle série !'), findsOneWidget);
        expect(find.textContaining('Tu ne verras plus Tom'), findsOneWidget);

        await reveal(tester, find.text('PERSONNES BLOQUÉES'));
        expect(_blockedNamed('Tom'), findsOneWidget);
      },
    );

    testWidgets('depuis un mot : annuler ne bloque personne', (tester) async {
      final community = FakeCommunityRepository(
        feed: [_wordFrom(_tom, 'Tu n’y arriveras jamais.')],
      );
      await openCommunity(tester, appWith(community));

      await chooseOption(tester, messageOptionsOf('Tom'), 'Bloquer');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(community.blockedIds, isEmpty);
      expect(find.text('Tu n’y arriveras jamais.'), findsOneWidget);
    });

    testWidgets('annuler ne bloque personne', (tester) async {
      final community = FakeCommunityRepository(friends: [_tom]);
      await openCommunity(tester, appWith(community));

      await chooseOption(tester, optionsOf('Tom'), 'Bloquer');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(community.blockedIds, isEmpty);
      expect(_friendNamed('Tom'), findsOneWidget);
    });

    testWidgets('débloquer retire la ligne, sans rétablir l’amitié', (
      tester,
    ) async {
      final community = FakeCommunityRepository(
        blocked: [
          BlockedUser(
            userId: 'ami-tom',
            displayName: 'Tom',
            blockedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ],
      );
      await openCommunity(tester, appWith(community));

      // Un compte qui n'a plus que des blocages n'est pas « vide ».
      expect(find.text('Personne ici pour l’instant'), findsNothing);
      await reveal(tester, find.text('PERSONNES BLOQUÉES'));
      expect(_blockedNamed('Tom'), findsOneWidget);

      await tester.tap(find.text('Débloquer'));
      await tester.pumpAndSettle();

      expect(community.unblockedIds, ['ami-tom']);
      expect(_blockedNamed('Tom'), findsNothing);
      expect(find.text('AMIS'), findsNothing);
      expect(find.textContaining('Blocage levé pour Tom'), findsOneWidget);
    });
  });

  group('signaler', () {
    testWidgets(
      'un ami : motif et précisions arrivent au dépôt, retour sobre',
      (tester) async {
        final community = FakeCommunityRepository(friends: [_tom]);
        await openCommunity(tester, appWith(community));

        await chooseOption(tester, optionsOf('Tom'), 'Signaler');
        expect(find.text('Signaler Tom'), findsOneWidget);

        await tester.tap(find.text('Harcèlement'));
        await tester.pump();
        await tester.enterText(find.byType(TextFormField), ' Trop insistant. ');
        await tester.ensureVisible(_confirm('Envoyer le signalement'));
        await tester.tap(_confirm('Envoyer le signalement'));
        await tester.pumpAndSettle();

        expect(community.reports, [
          (
            userId: 'ami-tom',
            encouragementId: null,
            reason: CommunityReportReason.harassment,
            details: 'Trop insistant.',
          ),
        ]);
        // Signaler ne retire pas l'ami ; le retour reste discret.
        expect(_friendNamed('Tom'), findsOneWidget);
        expect(
          find.textContaining('ton signalement est envoyé'),
          findsOneWidget,
        );
      },
    );

    testWidgets('un message : signalé sous le nom de son AUTEUR', (
      tester,
    ) async {
      final community = FakeCommunityRepository(
        feed: [_wordFrom(_tom, 'Trop fort ce matin.')],
      );
      await openCommunity(tester, appWith(community));

      await chooseOption(tester, messageOptionsOf('Tom'), 'Signaler');
      expect(find.text('Signaler ce message'), findsOneWidget);

      await tester.tap(find.text('Spam ou publicité'));
      await tester.pump();
      await tester.ensureVisible(_confirm('Envoyer le signalement'));
      await tester.tap(_confirm('Envoyer le signalement'));
      await tester.pumpAndSettle();

      expect(community.reports, [
        (
          userId: 'ami-tom',
          encouragementId: 'mot-ami-tom',
          reason: CommunityReportReason.spam,
          details: null,
        ),
      ]);
      expect(find.text('Trop fort ce matin.'), findsOneWidget);
    });
  });

  group('retirer un mot du fil', () {
    testWidgets('le mot disparaît, les autres restent', (tester) async {
      final community = FakeCommunityRepository(
        feed: [
          _wordFrom(_tom, 'Trop fort ce matin.'),
          _wordFrom(_sarah, 'Belle série !'),
        ],
      );
      await openCommunity(tester, appWith(community));

      await chooseOption(tester, messageOptionsOf('Tom'), 'Supprimer');

      expect(community.deletedEncouragements, ['mot-ami-tom']);
      expect(find.text('Trop fort ce matin.'), findsNothing);
      expect(find.text('Belle série !'), findsOneWidget);
      expect(find.text('Message retiré de ton fil.'), findsOneWidget);
    });
  });
}
