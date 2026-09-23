import 'package:carlys_mobile/app/router/app_routes.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/community/presentation/providers/community_tab_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/community_app.dart';
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

  testWidgets('les demandes en attente se lisent sur la piste', (tester) async {
    final semantics = tester.ensureSemantics();
    await openCommunity(tester, sampleWorldApp());

    // Le monde d'exemple porte une demande reçue : elle se voit sans ouvrir
    // l'onglet Amis.
    expect(find.bySemanticsLabel('Amis, 1 en attente'), findsOneWidget);
    semantics.dispose();
  });
}
