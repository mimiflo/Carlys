import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_app.dart';
import '../../support/fake_community_repository.dart';
import '../../support/first_run_prefs.dart';

/// Les gestes de protection de la communauté : retirer un ami, et bientôt
/// bloquer, signaler, retirer un mot du fil. Le dépôt factice reçoit l'appel,
/// l'écran reflète l'état, et l'échec hors ligne se dit.
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

      await chooseOption(tester, 'Tom', 'Retirer');

      // Rien ne part sans confirmation : la feuille dit ce qui va se passer.
      expect(find.text('Retirer Tom de tes amis ?'), findsOneWidget);
      expect(community.removedFriends, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Retirer'));
      await tester.pumpAndSettle();

      expect(community.removedFriends, ['ami-tom']);
      expect(find.text('Tom'), findsNothing);
      expect(find.text('Sarah'), findsOneWidget);
      expect(find.text('Tom ne fait plus partie de tes amis.'), findsOneWidget);
    });

    testWidgets('annuler ne touche à rien', (tester) async {
      final community = FakeCommunityRepository(friends: [_tom]);
      await openCommunity(tester, appWith(community));

      await chooseOption(tester, 'Tom', 'Retirer');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(community.removedFriends, isEmpty);
      expect(find.text('Tom'), findsOneWidget);
    });

    testWidgets('hors ligne : l’échec se dit, l’ami reste', (tester) async {
      final community = FakeCommunityRepository(friends: [_tom]);
      await openCommunity(tester, appWith(community));

      // Le réseau tombe APRÈS le chargement : le geste, lui, doit le dire.
      community.offline = true;
      await chooseOption(tester, 'Tom', 'Retirer');
      await tester.tap(find.widgetWithText(FilledButton, 'Retirer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hors connexion'), findsOneWidget);
      expect(find.text('Tom'), findsOneWidget);
    });
  });
}
