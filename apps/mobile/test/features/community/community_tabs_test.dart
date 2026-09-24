import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:carlys_mobile/features/community/presentation/providers/community_tab_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/community_app.dart';
import '../../support/fake_community_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/navigation.dart';

/// LES TROIS ONGLETS de la Communauté, et ce qui les ouvre : la piste, la
/// route (`?onglet=`) qu'empruntent les raccourcis de l'accueil et du
/// profil, et la loupe qui filtre l'onglet ouvert.
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

  /// Le routeur de l'application montée : ce qu'emprunte un raccourci.
  GoRouter routeur(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(AppBottomBar)));

  Future<void> suivre(WidgetTester tester, String location) async {
    routeur(tester).go(location);
    await tester.pumpAndSettle();
  }

  test('chaque onglet a son adresse, et une adresse inconnue n’en a pas', () {
    for (final tab in CommunityTab.values) {
      expect(CommunityTab.fromSlug(tab.slug), tab);
      expect(AppRoutes.communityTab(tab), '/community?onglet=${tab.slug}');
    }
    expect(CommunityTab.fromSlug('mithril'), isNull);
    expect(CommunityTab.fromSlug(null), isNull);
  });

  testWidgets('les Défis s’ouvrent les premiers', (tester) async {
    await openCommunity(tester, sampleWorldApp());

    expect(find.text('DÉFIS DU MOIS'), findsOneWidget);
    expect(find.text('Classement de la semaine'), findsNothing);
  });

  testWidgets('un raccourci ouvre l’onglet qu’il annonce', (tester) async {
    await tester.pumpWidget(sampleWorldApp());
    await tester.pumpAndSettle();

    await suivre(tester, AppRoutes.communityTab(CommunityTab.ligue));

    expect(find.text('Classement de la semaine'), findsOneWidget);
  });

  testWidgets('le même raccourci, après un détour à la main, ramène à son '
      'onglet', (tester) async {
    // Arrivée par un raccourci, passage aux Défis, retour à l'accueil, et le
    // même raccourci : l'adresse n'avait pas bougé, rien ne se passait, et
    // l'on atterrissait sur l'onglet que le raccourci n'annonçait pas.
    await tester.pumpWidget(sampleWorldApp());
    await tester.pumpAndSettle();
    await suivre(tester, AppRoutes.communityTab(CommunityTab.amis));
    await showCommunityTab(tester, 'Défis');
    await tapTab(tester, 'Accueil');

    await suivre(tester, AppRoutes.communityTab(CommunityTab.amis));

    expect(find.text('ENCOURAGEMENTS'), findsOneWidget);
  });

  testWidgets('quitter la page puis y revenir rouvre l’onglet quitté', (
    tester,
  ) async {
    await openCommunity(tester, sampleWorldApp(), tab: 'Ligue');
    await tapTab(tester, 'Accueil');
    await tapTab(tester, 'Communauté');

    expect(find.text('Classement de la semaine'), findsOneWidget);
  });

  testWidgets('une adresse d’onglet inconnue ouvre les Défis', (tester) async {
    await tester.pumpWidget(sampleWorldApp());
    await tester.pumpAndSettle();

    await suivre(tester, '${AppRoutes.community}?onglet=mithril');

    expect(find.text('DÉFIS DU MOIS'), findsOneWidget);
  });

  group('La loupe', () {
    testWidgets('filtre l’onglet ouvert, et se referme vide', (tester) async {
      await openCommunity(tester, sampleWorldApp(), tab: 'Amis');
      expect(find.text('Tom'), findsWidgets);

      await tester.tap(find.byTooltip('Rechercher'));
      await tester.pumpAndSettle();
      // Le champ dit ce qu'il cherche, ici : l'onglet ouvert.
      expect(find.text('Chercher parmi tes amis'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'sar');
      await tester.pumpAndSettle();
      expect(find.text('Tom'), findsNothing);
      expect(find.text('Sarah'), findsWidgets);
      // Un réglage n'est pas un prénom : il sort des résultats.
      expect(find.text('CONFIDENTIALITÉ'), findsNothing);

      // Rien ne correspond : l'onglet le DIT, il ne reste pas muet.
      await tester.enterText(find.byType(TextField), 'zoé');
      await tester.pumpAndSettle();
      expect(
        find.text('Personne ne s’appelle ainsi parmi tes amis.'),
        findsOneWidget,
      );

      // Refermer la loupe rend tout : la recherche ne survit pas au champ.
      await tester.tap(find.byTooltip('Fermer la recherche'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Tom'), findsWidgets);
      expect(
        find.text('Personne ne s’appelle ainsi parmi tes amis.'),
        findsNothing,
      );
    });

    testWidgets('dans la Ligue, retrouve un prénom hors du podium', (
      tester,
    ) async {
      await openCommunity(tester, sampleWorldApp(), tab: 'Ligue');
      // Neuvième : invisible sans recherche, la carte ne montre que le
      // podium et ma ligne.
      expect(find.text('Nora'), findsNothing);

      await tester.tap(find.byTooltip('Rechercher'));
      await tester.pumpAndSettle();
      expect(find.text('Chercher un prénom dans ta ligue'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'nora');
      await tester.pumpAndSettle();

      expect(find.text('Nora'), findsOneWidget);
      expect(find.text('Sarah'), findsNothing);
    });

    testWidgets('dans les Défis, filtre par titre', (tester) async {
      await openCommunity(tester, sampleWorldApp());

      await tester.tap(find.byTooltip('Rechercher'));
      await tester.pumpAndSettle();
      expect(find.text('Filtrer les défis'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'haut du corps');
      await tester.pumpAndSettle();

      expect(
        find.text('Qui connaît le mieux le haut du corps ?'),
        findsOneWidget,
      );
      // La porte « Défier mes amis » reste : on filtre, on ne ferme rien.
      expect(find.text('Défier mes amis'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'marathon');
      await tester.pumpAndSettle();
      expect(find.text('Aucun défi ne porte ce nom.'), findsOneWidget);
      expect(find.text('Défier mes amis'), findsOneWidget);
    });
  });

  testWidgets('un raccourci ferme la loupe restée ouverte', (tester) async {
    // Un titre de défi tapé dans la loupe masquait, à l'arrivée par le
    // raccourci de l'accueil, l'ami dont l'accueil venait d'annoncer le mot.
    await openCommunity(tester, sampleWorldApp());
    await tester.tap(find.byTooltip('Rechercher'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'marathon');
    await tester.pumpAndSettle();
    await tapTab(tester, 'Accueil');

    await suivre(tester, AppRoutes.communityTab(CommunityTab.amis));

    expect(find.byType(TextField), findsNothing);
    expect(find.text('ENCOURAGEMENTS'), findsOneWidget);
  });

  testWidgets('amis en panne, défis là : la feuille ne dit pas « pas d’ami »', (
    tester,
  ) async {
    final community = FakeCommunityRepository(
      friends: const [
        CommunityFriend(
          id: 'ami-1',
          displayName: 'Sarah',
          streakDays: 3,
          weeklySessions: 2,
          sharesProgress: true,
        ),
      ],
    )..friendsError = StateError('amis injoignables (voulu par le test)');
    await openCommunity(tester, appWith(community));

    // Les défis répondent : l'onglet ne tombe pas pour une liste d'amis.
    expect(find.byType(AppErrorState), findsNothing);
    final defier = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Défier mes amis'),
    );
    expect(defier.onPressed, isNull);
    expect(
      find.textContaining('Ta liste d’amis n’a pas pu se charger'),
      findsOneWidget,
    );
  });

  testWidgets('quitter puis rejoindre la ligue', (tester) async {
    // Le geste vit désormais dans l'onglet Ligue : le test de l'ancienne
    // carte est parti avec elle, celui-ci le remplace.
    final community = FakeCommunityRepository()..joinsLeague = true;
    await openCommunity(tester, appWith(community), tab: 'Ligue');
    expect(find.text('Classement de la semaine'), findsOneWidget);

    await reveal(tester, find.text('Quitter la ligue'));
    await tester.tap(find.text('Quitter la ligue'));
    await tester.pumpAndSettle();

    expect(community.joinsLeague, isFalse);
    expect(find.text('Classement de la semaine'), findsNothing);
    // Le départ se DIT, dans la popup centrée ; elle couvre l'écran de son
    // voile tant qu'on ne l'a pas touchée (ou qu'elle ne s'est pas fermée).
    final depart = find.widgetWithText(
      AppPopupCard,
      'C’est fait : tu ne joues plus la ligue. Plus rien n’y est compté.',
    );
    expect(depart, findsOneWidget);
    await tester.tap(depart);
    await tester.pumpAndSettle();
    expect(depart, findsNothing);

    await tester.tap(find.text('Rejoindre la ligue'));
    await tester.pumpAndSettle();

    expect(community.joinsLeague, isTrue);
    expect(find.text('Classement de la semaine'), findsOneWidget);
    expect(
      find.widgetWithText(
        AppPopupCard,
        'Te voilà dans la ligue. La semaine repart dimanche soir.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tirer pour rafraîchir ne relit que ce que l’onglet montre', (
    tester,
  ) async {
    // Une source que personne n'écoute n'existe pas : la relire la créait,
    // lançait sa requête, et Riverpod la jetait en fin de trame.
    final community = FakeCommunityRepository();
    await openCommunity(tester, appWith(community));
    final avant = community.leagueReads;

    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 320),
      1000,
    );
    await tester.pumpAndSettle();

    expect(community.leagueReads, avant);
  });

  testWidgets('les demandes en attente se lisent sur la piste', (tester) async {
    final semantics = tester.ensureSemantics();
    await openCommunity(tester, sampleWorldApp());

    // Le monde d'exemple porte une demande reçue : elle se voit sans ouvrir
    // l'onglet Amis.
    expect(find.bySemanticsLabel('Amis, 1 en attente'), findsOneWidget);
    semantics.dispose();
  });
}
