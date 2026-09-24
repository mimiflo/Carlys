import 'dart:async';

import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/community/presentation/screens/friend_challenge_screen.dart';
import 'package:carlys_mobile/features/notifications/domain/entities/push_destination.dart';
import 'package:carlys_mobile/features/notifications/domain/services/push_messenger.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_app.dart';
import '../../support/fake_push_messenger.dart';
import '../../support/first_run_prefs.dart';

/// TOUCHER UNE NOTIFICATION OUVRE L'ÉCRAN QU'ELLE ANNONCE.
///
/// Avant, « Léa t'invite à un défi » ouvrait l'accueil, et le défi restait à
/// chercher. Le serveur dit désormais où mener (`destination`, contrat
/// `PUSH_DESTINATIONS`) ; l'application ne suit qu'une liste fermée, et
/// jamais une adresse brute venue du réseau.
void main() {
  const challengeId = '6f1c2a4e-8b3d-4c5e-9f70-1a2b3c4d5e6f';

  group('PushDestination.fromData', () {
    test('les amis', () {
      expect(
        PushDestination.fromData({'destination': 'community-friends'}),
        const CommunityFriendsDestination(),
      );
    });

    test('un défi, avec son identifiant', () {
      expect(
        PushDestination.fromData({
          'destination': 'friend-challenge',
          'challengeId': challengeId,
        }),
        const FriendChallengeDestination(challengeId),
      );
    });

    test('un défi sans identifiant valable ne mène nulle part', () {
      // Rien d'autre qu'un UUID ne se glisse dans une adresse de l'appli.
      for (final challenge in <Object?>[
        null,
        '',
        '../../settings',
        'exemple-defi',
        '$challengeId\n',
        '$challengeId/../..',
        42,
      ]) {
        expect(
          PushDestination.fromData({
            'destination': 'friend-challenge',
            'challengeId': challenge,
          }),
          isNull,
          reason: 'identifiant : $challenge',
        );
      }
    });

    test('une destination inconnue ou absente ne mène nulle part', () {
      // Un serveur plus récent que l'application peut en annoncer une
      // nouvelle : elle s'ouvre alors simplement, là où elle était.
      expect(PushDestination.fromData({'destination': 'mithril'}), isNull);
      expect(PushDestination.fromData({'destination': 3}), isNull);
      expect(PushDestination.fromData(const {}), isNull);
    });
  });

  test('chaque destination a son écran', () {
    expect(
      AppRoutes.pushDestination(const CommunityFriendsDestination()),
      '/community?onglet=amis',
    );
    expect(
      AppRoutes.pushDestination(const FriendChallengeDestination(challengeId)),
      '/community/defis/$challengeId',
    );
  });

  group('Toucher une notification', () {
    // Le défi de Léa, dans le monde d'exemple.
    const invitation = FriendChallengeDestination('exemple-defi-ami-seances');
    const firebase = FirebasePushOptions(
      apiKey: 'cle-de-test',
      appId: '1:000000000000:android:0000000000000000000000',
      messagingSenderId: '000000000000',
      projectId: 'carlys-test',
    );
    const withPush = AppEnvironment(
      flavor: AppFlavor.development,
      apiBaseUrl: 'http://localhost:3000',
      push: firebase,
    );

    setUp(() {
      seedCompletedFirstRun();
      // L'accueil anime en boucle : sans « réduire les animations », rien
      // ne se pose jamais.
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

    Future<FakePushMessenger> launch(
      WidgetTester tester, {
      PushDestination? launchedBy,
      bool pushConfigured = false,
    }) async {
      // Permission refusée : l'enregistrement du jeton ne part pas au réseau.
      final messenger = FakePushMessenger(
        token: null,
        launchDestination: launchedBy,
      );
      addTearDown(messenger.close);
      await tester.pumpWidget(
        pushConfigured
            ? sampleWorldApp(messenger: messenger, environment: withPush)
            : sampleWorldApp(messenger: messenger),
      );
      await tester.pumpAndSettle();
      return messenger;
    }

    testWidgets('une invitation ouvre le défi', (tester) async {
      final messenger = await launch(tester);

      messenger.opened.add(invitation);
      await tester.pumpAndSettle();

      expect(find.byType(FriendChallengeScreen), findsOneWidget);
      expect(find.text('Cinq séances cette semaine'), findsOneWidget);
    });

    testWidgets('une demande d’ami ouvre l’onglet Amis', (tester) async {
      final messenger = await launch(tester);

      messenger.opened.add(const CommunityFriendsDestination());
      await tester.pumpAndSettle();

      expect(find.text('ENCOURAGEMENTS'), findsOneWidget);
    });

    testWidgets('celle qui LANCE l’application ouvre son écran', (
      tester,
    ) async {
      final messenger = await launch(
        tester,
        launchedBy: invitation,
        pushConfigured: true,
      );

      expect(find.byType(FriendChallengeScreen), findsOneWidget);
      expect(messenger.launchCalls, 1);
    });

    testWidgets('sans configuration Firebase, rien n’est demandé au SDK', (
      tester,
    ) async {
      // Aucune notification n'a pu lancer l'application : le SDK n'est
      // même pas initialisé, lui demander quoi que ce soit échouerait.
      final messenger = await launch(tester, launchedBy: invitation);

      expect(messenger.launchCalls, 0);
      expect(find.byType(FriendChallengeScreen), findsNothing);
    });

    testWidgets('reçue application ouverte, « Voir le défi » mène au même '
        'écran', (tester) async {
      final messenger = await launch(tester);

      messenger.notices.add(
        const PushNotice(
          title: 'Léa t’invite à un défi',
          body: 'Ouvre la Communauté pour répondre.',
          destination: invitation,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // La popup centrée des messages passagers, qui dit OÙ elle mène.
      expect(find.byType(AppPopupCard), findsOneWidget);
      await tester.tap(find.text('Voir le défi'));
      await tester.pumpAndSettle();

      expect(find.byType(FriendChallengeScreen), findsOneWidget);
      expect(find.byType(AppPopupCard), findsNothing);
    });

    testWidgets('reçue application ouverte, « Voir » ouvre l’onglet Amis', (
      tester,
    ) async {
      final messenger = await launch(tester);

      messenger.notices.add(
        const PushNotice(
          title: 'Léa t’a encouragé',
          body: 'Belle série !',
          destination: CommunityFriendsDestination(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Voir le défi'), findsNothing);
      await tester.tap(find.text('Voir'));
      await tester.pumpAndSettle();

      expect(find.text('ENCOURAGEMENTS'), findsOneWidget);
    });

    testWidgets('« Voir le défi » par-dessus une question ouverte la referme '
        'd’abord : elle ne ressurgit pas au retour', (tester) async {
      final messenger = await launch(tester);

      // Une question en cours, sur le navigateur racine, comme l'écran du
      // défi lui-même.
      bool? answer;
      unawaited(
        showAppConfirm(
          tester.element(find.byType(AppBottomBar)),
          title: 'Supprimer cette série ?',
          message: 'Elle disparaîtra de la séance.',
          confirmLabel: 'Supprimer',
          destructive: true,
        ).then((value) => answer = value),
      );
      await tester.pumpAndSettle();

      messenger.notices.add(
        const PushNotice(
          title: 'Léa t’invite à un défi',
          body: 'Ouvre la Communauté pour répondre.',
          destination: invitation,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppPopupCard), findsNWidgets(2));

      await tester.tap(find.text('Voir le défi'));
      await tester.pumpAndSettle();
      expect(find.byType(FriendChallengeScreen), findsOneWidget);
      // Refermée comme si l'on avait renoncé : rien n'est supprimé.
      expect(answer, isFalse);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(FriendChallengeScreen), findsNothing);
      expect(find.text('Supprimer cette série ?'), findsNothing);
      expect(find.byType(AppPopupCard), findsNothing);
    });

    testWidgets('« Plus tard » referme la popup et laisse l’écran en place', (
      tester,
    ) async {
      final messenger = await launch(tester);

      messenger.notices.add(
        const PushNotice(
          title: 'Léa t’invite à un défi',
          body: 'Ouvre la Communauté pour répondre.',
          destination: invitation,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Navigation d'accessibilité active (réglage du groupe) : une popup
      // qui propose quelque chose attend qu'on choisisse.
      await tester.pump(const Duration(seconds: 30));
      expect(find.byType(AppPopupCard), findsOneWidget);

      await tester.tap(find.text(AppNotices.laterLabel));
      await tester.pumpAndSettle();
      expect(find.byType(AppPopupCard), findsNothing);
      expect(find.byType(FriendChallengeScreen), findsNothing);
    });

    testWidgets('le retour arrière ferme la popup, pas l’application', (
      tester,
    ) async {
      final messenger = await launch(tester);

      messenger.notices.add(
        const PushNotice(
          title: 'Léa t’invite à un défi',
          body: 'Ouvre la Communauté pour répondre.',
          destination: invitation,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue, reason: 'le retour a été pris par la popup');
      expect(find.byType(AppPopupCard), findsNothing);
      expect(find.byType(AppBottomBar), findsOneWidget);
    });

    testWidgets('sans destination, la popup ne propose rien à ouvrir', (
      tester,
    ) async {
      final messenger = await launch(tester);

      messenger.notices.add(
        const PushNotice(title: 'Carlys', body: 'Une nouvelle de Carlys.'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Une nouvelle de Carlys.'), findsOneWidget);
      expect(find.text('Voir'), findsNothing);
      expect(find.text('Voir le défi'), findsNothing);
      expect(find.text(AppNotices.laterLabel), findsNothing);
    });
  });
}
