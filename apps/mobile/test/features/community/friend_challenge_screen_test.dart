import 'dart:async';

import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:carlys_mobile/features/community/presentation/screens/friend_challenge_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/community_app.dart';
import '../../support/fake_community_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/in_memory_community_repository.dart';

/// L'ÉCRAN D'UN DÉFI ENTRE AMIS (maquette du 23 septembre 2026) : ce qu'il
/// montre, et les trois gestes qu'il porte — accepter, refuser, signaler.
void main() {
  const invitation = 'exemple-defi-ami-seances';

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

  /// Ouvre la Communauté, puis le défi : comme depuis sa carte, avec la
  /// page d'avant dans la pile.
  Future<void> ouvrir(
    WidgetTester tester,
    Widget app, {
    String id = invitation,
  }) async {
    await openCommunity(tester, app);
    // `push` rend un futur qui ne se termine qu'au RETOUR de l'écran : ne
    // pas l'attendre ici, c'est le geste lui-même.
    unawaited(
      GoRouter.of(
        tester.element(find.byType(CommunityScreen)),
      ).push(AppRoutes.friendChallenge(id)),
    );
    await tester.pumpAndSettle();
  }

  Finder page() => find
      .descendant(
        of: find.byType(FriendChallengeScreen),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> voir(WidgetTester tester, Finder cible) async {
    await tester.scrollUntilVisible(cible, 240, scrollable: page());
    await tester.pumpAndSettle();
  }

  testWidgets('l’invitation se lit : qui défie, qui participe, la règle, '
      'le mot', (tester) async {
    await ouvrir(tester, sampleWorldApp());

    expect(find.text('Cinq séances cette semaine'), findsOneWidget);
    expect(find.text('Léa te défie'), findsOneWidget);
    expect(find.text('3 participants'), findsOneWidget);
    expect(find.text('À l’origine'), findsOneWidget);
    expect(find.text('Dans le défi'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);

    // Jamais de points : un défi entre amis ne rapporte rien.
    await voir(tester, find.text('Comment ça se joue'));
    expect(
      find.text('Aucun point ni titre en jeu : juste toi et tes amis.'),
      findsOneWidget,
    );
    expect(find.textContaining('+150'), findsNothing);

    await voir(tester, find.text('Message de Léa'));
    expect(find.textContaining('Allez on y va !'), findsOneWidget);
    expect(find.textContaining('Aujourd’hui, '), findsOneWidget);
  });

  testWidgets('accepter : le geste le dit, et j’entre au classement', (
    tester,
  ) async {
    await ouvrir(tester, sampleWorldApp());

    await voir(tester, find.text('Accepter le défi'));
    await tester.tap(find.text('Accepter le défi'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tu es dans le défi « Cinq séances cette semaine ».'),
      findsOneWidget,
    );
    expect(find.text('Accepter le défi'), findsNothing);
    expect(find.text('En attente'), findsNothing);
    // Ma ligne, à zéro, derrière ceux qui ont déjà marqué.
    await voir(tester, find.text('Toi').last);
    expect(find.text('0 / 5 séances'), findsOneWidget);
  });

  testWidgets('refuser referme l’écran et retire le défi de la liste', (
    tester,
  ) async {
    await ouvrir(tester, sampleWorldApp());

    await voir(tester, find.text('Refuser'));
    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();

    expect(find.byType(FriendChallengeScreen), findsNothing);
    expect(find.text('Cinq séances cette semaine'), findsNothing);
  });

  testWidgets('signaler le défi : sous le nom de Léa, depuis le menu', (
    tester,
  ) async {
    final community = InMemoryCommunityRepository();
    await ouvrir(tester, sampleWorldApp(community: community));

    await tester.tap(find.byTooltip('Plus d’options'));
    await tester.pumpAndSettle();
    // Invité, pas encore dedans : « Quitter » n'a pas de sens, « Refuser »
    // vit en bas de l'écran.
    expect(find.text('Quitter le défi'), findsNothing);
    await tester.tap(find.text('Signaler ce défi'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Harcèlement'));
    await tester.pump();
    final envoyer = find.widgetWithText(FilledButton, 'Envoyer le signalement');
    await tester.ensureVisible(envoyer);
    await tester.tap(envoyer);
    await tester.pumpAndSettle();

    expect(community.reportedFriendChallenges, [invitation]);
    expect(find.textContaining('ton signalement est envoyé'), findsOneWidget);
  });

  testWidgets('dans le défi : le menu propose de le quitter, avec '
      'confirmation', (tester) async {
    await ouvrir(tester, sampleWorldApp(), id: 'exemple-defi-ami-course');

    await tester.tap(find.byTooltip('Plus d’options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitter le défi'));
    await tester.pumpAndSettle();

    expect(find.text('Quitter « Qui court le plus » ?'), findsOneWidget);
    // La popup centrée du design system, bouton rouge : on sort du
    // classement.
    final quitter = find.descendant(
      of: find.byType(AppPopupCard),
      matching: find.widgetWithText(AppButton, 'Quitter'),
    );
    expect(
      tester.widget<AppButton>(quitter).variant,
      AppButtonVariant.destructive,
    );
    await tester.tap(quitter);
    await tester.pumpAndSettle();

    expect(find.byType(FriendChallengeScreen), findsNothing);
  });

  testWidgets('un défi qui n’est plus le mien le dit, sans parler de panne', (
    tester,
  ) async {
    await ouvrir(tester, sampleWorldApp(), id: 'defi-inconnu');

    expect(find.text('Ce défi n’est plus là'), findsOneWidget);
    expect(find.byType(AppErrorState), findsNothing);

    await tester.tap(find.text('Retour aux défis'));
    await tester.pumpAndSettle();
    expect(find.byType(FriendChallengeScreen), findsNothing);
  });

  testWidgets('hors ligne : le statut le DIT', (tester) async {
    final community = FakeCommunityRepository();
    await openCommunity(tester, appWith(community));
    community.offline = true;
    unawaited(
      GoRouter.of(
        tester.element(find.byType(CommunityScreen)),
      ).push(AppRoutes.friendChallenge('defi-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hors connexion'), findsOneWidget);
    expect(find.text('Ce défi n’est plus là'), findsNothing);
  });

  testWidgets('la carte de l’onglet Défis mène à l’écran', (tester) async {
    await openCommunity(tester, sampleWorldApp());

    await reveal(tester, find.text('Cinq séances cette semaine'));
    await tester.tap(find.text('Cinq séances cette semaine'));
    await tester.pumpAndSettle();

    expect(find.byType(FriendChallengeScreen), findsOneWidget);
    expect(find.text('Léa te défie'), findsOneWidget);
  });
}
