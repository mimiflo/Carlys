import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/community/domain/entities/league.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/league/league_crown.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/league/league_invitation_card.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/league/league_ranking_card.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/league/league_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : la ligue est un CHOIX, et elle se lit.
///
/// Le « périmètre choisi » du principe 5 n'est pas qu'une règle serveur : un
/// écran qui montrerait des noms d'inconnus avant l'adhésion le briserait
/// tout seul. Et un classement où l'on ne se trouve pas ne motive personne :
/// ma ligne doit être là même hors du podium.
///
/// Les phrases elles-mêmes (écart, zone, sommet) sont éprouvées cas par cas
/// dans `league_wording_test.dart` ; ici, on vérifie qu'elles ARRIVENT à
/// l'écran, et ce que l'écran en fait.
void main() {
  LeagueStanding ligne(String name, int score, int rank, {bool isMe = false}) =>
      LeagueStanding(
        userId: 'u-$name',
        displayName: name,
        score: score,
        rank: rank,
        isMe: isMe,
      );

  League ligue({
    LeagueDivision division = LeagueDivision.or,
    int score = 240,
    List<LeagueStanding>? standings,
    LeagueResult? lastResult,
    LeaguePromotion? promotion,
  }) => League(
    joined: true,
    periodKey: '2026-W38',
    endsAt: DateTime.now().add(const Duration(days: 3, hours: 1)),
    division: division,
    score: score,
    standings: standings ?? const [],
    lastResult: lastResult,
    promotion: promotion,
  );

  Widget monte(Widget child) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  group('L’invitation', () {
    testWidgets(
      'sans adhésion, aucun nom : la carte INVITE, elle ne classe pas',
      (tester) async {
        // Un classement visible avant d'avoir dit oui briserait le « périmètre
        // CHOISI » aussi sûrement qu'une requête serveur mal filtrée : la
        // carte ne REÇOIT même pas de classement.
        await tester.pumpWidget(
          monte(
            LeagueInvitationCard(
              division: LeagueDivision.bronze,
              onJoin: () {},
            ),
          ),
        );

        expect(find.text('Rejoindre la ligue'), findsOneWidget);
        expect(find.text('Classement de la semaine'), findsNothing);
        // Ni compte à rebours : il compterait une semaine qu'on ne joue pas.
        expect(find.textContaining('J\u2212'), findsNothing);
        // Ni division visée : on n'y joue pas encore.
        expect(find.byIcon(AppIcons.arrowForward), findsNothing);
        // Le barème, lui, se lit avant d'entrer.
        expect(find.text('pts la séance'), findsOneWidget);
      },
    );

    testWidgets('rejoindre appelle l’adhésion, et une seule fois', (
      tester,
    ) async {
      var entrees = 0;
      await tester.pumpWidget(
        monte(
          LeagueInvitationCard(
            division: LeagueDivision.bronze,
            onJoin: () => entrees++,
          ),
        ),
      );

      await tester.ensureVisible(find.text('Rejoindre la ligue'));
      await tester.tap(find.text('Rejoindre la ligue'));
      await tester.pumpAndSettle();

      expect(entrees, 1);
    });
  });

  group('Où j’en suis', () {
    testWidgets('la division et celle qui vient se disent à voix haute', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        monte(LeagueStatusCard(league: ligue(division: LeagueDivision.bronze))),
      );

      // La flèche est un dessin : sans étiquette, « Bronze Argent » ne dirait
      // pas lequel est l'actuel.
      expect(
        find.bySemanticsLabel('Ligue Bronze, prochaine ligue Argent'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('en Diamant, pas de prochaine ligue', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        monte(
          LeagueStatusCard(league: ligue(division: LeagueDivision.diamant)),
        ),
      );

      expect(find.bySemanticsLabel('Ligue Diamant'), findsOneWidget);
      expect(find.byIcon(AppIcons.arrowForward), findsNothing);
      semantics.dispose();
    });

    testWidgets('l’écart avec la zone de montée, et la base de la jauge', (
      tester,
    ) async {
      await tester.pumpWidget(
        monte(
          LeagueStatusCard(
            league: ligue(
              division: LeagueDivision.bronze,
              promotion: const LeaguePromotion(
                promotedCount: 5,
                minPlayers: 10,
                activePlayers: 12,
                topDivision: false,
                inZone: false,
                zoneScore: 275,
                pointsToZone: 35,
              ),
            ),
          ),
        ),
      );

      // Jamais « 260 points pour passer Argent » : aucun seuil de ce genre
      // n'existe, la montée se joue au rang.
      expect(
        find.text('Encore 35 points pour entrer dans le top 5.'),
        findsOneWidget,
      );
      expect(find.text('240 / 275 pts'), findsOneWidget);
      // La jauge dit sur quoi elle porte (`docs/product/progression.md`).
      expect(find.text('275 pts : le score du 5e aujourd’hui'), findsOneWidget);
      expect(find.byType(AppGauge), findsOneWidget);
    });

    testWidgets('sans calcul du serveur, le score seul et aucune jauge', (
      tester,
    ) async {
      await tester.pumpWidget(monte(LeagueStatusCard(league: ligue())));

      // Des points, jamais l'unité brute d'une métrique : le serveur
      // convertit avant d'additionner.
      expect(find.text('240 points cette semaine'), findsOneWidget);
      expect(find.byType(AppGauge), findsNothing);
    });

    testWidgets('la montée de la semaine passée s’annonce', (tester) async {
      await tester.pumpWidget(
        monte(
          LeagueStatusCard(
            league: ligue(
              lastResult: const LeagueResult(
                periodKey: '2026-W37',
                rank: 2,
                from: LeagueDivision.argent,
                to: LeagueDivision.or,
              ),
            ),
          ),
        ),
      );

      // Sans cette phrase, la division changerait sans explication.
      // « 1re place » : l'ordinal s'accorde à la place, jamais à la personne.
      expect(
        find.text('À la 2e place la semaine passée : te voilà en Or.'),
        findsOneWidget,
      );
      expect(find.byIcon(AppIcons.trendingUp), findsOneWidget);
    });

    testWidgets('une descente se dit sans dramatiser', (tester) async {
      await tester.pumpWidget(
        monte(
          LeagueStatusCard(
            league: ligue(
              division: LeagueDivision.argent,
              lastResult: const LeagueResult(
                periodKey: '2026-W37',
                rank: 18,
                from: LeagueDivision.or,
                to: LeagueDivision.argent,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('retour en Argent'), findsOneWidget);
      expect(find.byIcon(AppIcons.trendingDown), findsOneWidget);
    });
  });

  group('Le classement de la semaine', () {
    final classement = [
      ligne('Boris', 480, 1),
      ligne('Chloé', 320, 2),
      ligne('Dan', 300, 3),
      ligne('Eva', 90, 4),
      ligne('Camille', 40, 5, isMe: true),
      ligne('Sarah', 20, 6),
    ];

    testWidgets('le podium se lit en POINTS', (tester) async {
      await tester.pumpWidget(
        monte(LeagueRankingCard(league: ligue(standings: classement))),
      );

      expect(find.text('480 pts'), findsOneWidget);
      expect(find.text('Boris'), findsOneWidget);
      expect(find.text('Dan'), findsOneWidget);
      // Le compte à rebours de la semaine.
      expect(find.text('J\u22123'), findsOneWidget);
    });

    testWidgets('ma ligne apparaît MÊME hors du podium', (tester) async {
      await tester.pumpWidget(
        monte(LeagueRankingCard(league: ligue(standings: classement))),
      );

      // Trois du podium, plus moi : cinquième, et bien là. Sans cette ligne,
      // la carte ne dirait rien à celle qui en a le plus besoin.
      expect(find.text('Toi'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Eva'), findsNothing);
      expect(find.text('Sarah'), findsNothing);
    });

    testWidgets('ma ligne se dit en entier au lecteur d’écran', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        monte(LeagueRankingCard(league: ligue(standings: classement))),
      );

      expect(find.bySemanticsLabel('5e place, Toi, 40 points'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('le bouton du classement complet garde son geste pour lui', (
      tester,
    ) async {
      // Sans frontière sémantique, la carte entière se fondait dans le
      // bouton : le lecteur d'écran annonçait tout l'onglet comme UN bouton,
      // et le double-tap n'importe où ouvrait la feuille.
      final semantics = tester.ensureSemantics();
      // Monté comme dans l'onglet : un élément de `ListView`, à côté d'un
      // texte — c'est avec lui que la carte se fondait.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: ListView(
              children: [
                Column(
                  children: [
                    const Text('Petits efforts, grands résultats.'),
                    LeagueRankingCard(league: ligue(standings: classement)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Voir le classement complet'),
        ),
        isSemantics(label: 'Voir le classement complet', isButton: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Classement de la semaine')),
        isSemantics(isHeader: true, isButton: false),
      );
      // Ni la carte elle-même : ses lignes ne vivent pas sous un bouton.
      final podium = tester.getSemantics(
        find.bySemanticsLabel('1re place, Boris, 480 points'),
      );
      expect(podium.parent, isSemantics(isButton: false));
      semantics.dispose();
    });

    testWidgets('une semaine vide le dit, au lieu de laisser un trou', (
      tester,
    ) async {
      await tester.pumpWidget(monte(LeagueRankingCard(league: ligue())));

      expect(find.textContaining('Personne n’a encore marqué'), findsOneWidget);
      expect(find.text('Voir le classement complet'), findsNothing);
    });

    testWidgets('un lundi à zéro partout : pas de podium de couronnes', (
      tester,
    ) async {
      // Le serveur rend AUSSI les lignes à zéro : tout le monde est premier
      // ex æquo. Trois couronnes d'or sur des zéros ne voudraient rien dire.
      await tester.pumpWidget(
        monte(
          LeagueRankingCard(
            league: ligue(
              score: 0,
              standings: [
                ligne('Boris', 0, 1),
                ligne('Chloé', 0, 1),
                ligne('Camille', 0, 1, isMe: true),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('Personne n’a encore marqué'), findsOneWidget);
      expect(find.byType(LeagueCrown), findsNothing);
    });

    testWidgets('ma ligne reste là quand un ex æquo me range au podium sans '
        'me donner une des trois premières lignes', (tester) async {
      // Le serveur donne le même rang aux ex æquo et départage l'AFFICHAGE
      // par identifiant : premier ex æquo, je peux être la quatrième ligne.
      await tester.pumpWidget(
        monte(
          LeagueRankingCard(
            league: ligue(
              score: 50,
              standings: [
                ligne('Boris', 50, 1),
                ligne('Chloé', 50, 1),
                ligne('Dan', 50, 1),
                ligne('Camille', 50, 1, isMe: true),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Toi'), findsOneWidget);
    });

    testWidgets('sans points, pas de couronne, même au premier rang', (
      tester,
    ) async {
      // Deux personnes ont marqué : le podium s'arrête à elles, et ma ligne
      // à zéro s'affiche sans couronne.
      await tester.pumpWidget(
        monte(
          LeagueRankingCard(
            league: ligue(
              score: 0,
              standings: [
                ligne('Boris', 120, 1),
                ligne('Chloé', 60, 2),
                ligne('Camille', 0, 3, isMe: true),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(LeagueCrown), findsNWidgets(2));
      expect(find.text('Toi'), findsOneWidget);
    });

    testWidgets('en grand texte sur un petit écran, aucune ligne ne déborde', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320, 1400)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        monte(
          Column(
            children: [
              LeagueStatusCard(league: ligue()),
              LeagueRankingCard(
                league: ligue(
                  standings: [
                    ligne('Boris', 1480, 1),
                    ligne('Chloé', 320, 2),
                    ligne('Dan', 300, 3),
                    ligne('Camille', 240, 4, isMe: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      // Un RenderFlex qui déborde lève une exception en test : son absence
      // EST la preuve.
      expect(tester.takeException(), isNull);
    });

    testWidgets('la loupe retrouve un prénom HORS du podium', (tester) async {
      await tester.pumpWidget(
        monte(
          LeagueRankingCard(
            league: ligue(standings: classement),
            query: 'SARAH',
          ),
        ),
      );

      // Sixième, donc invisible sans recherche : la recherche montre toutes
      // les lignes qui correspondent, podium ou pas — et rien d'autre.
      expect(find.text('Sarah'), findsOneWidget);
      expect(find.text('Boris'), findsNothing);
      expect(find.text('Toi'), findsNothing);
    });

    testWidgets('une recherche sans résultat le dit', (tester) async {
      await tester.pumpWidget(
        monte(
          LeagueRankingCard(
            league: ligue(standings: classement),
            query: 'Zoé',
          ),
        ),
      );

      expect(
        find.text('Personne ne s’appelle ainsi dans ta ligue.'),
        findsOneWidget,
      );
    });

    testWidgets('le classement complet s’ouvre sur TOUTE la division', (
      tester,
    ) async {
      await tester.pumpWidget(
        monte(LeagueRankingCard(league: ligue(standings: classement))),
      );

      await tester.ensureVisible(find.text('Voir le classement complet'));
      await tester.tap(find.text('Voir le classement complet'));
      await tester.pumpAndSettle();

      // Rien de plus à charger : le serveur rend déjà la division entière.
      expect(find.text('6 membres cette semaine'), findsOneWidget);
      expect(find.text('Ligue Or'), findsOneWidget);
      expect(find.text('Eva'), findsOneWidget);
      expect(find.text('Sarah'), findsOneWidget);
    });
  });

  group('L’échelle des divisions', () {
    test('range les divisions de la plus basse à la plus haute', () {
      expect(LeagueDivision.bronze.rung, 0);
      expect(LeagueDivision.diamant.rung, LeagueDivision.values.length - 1);
      expect(LeagueDivision.fromApi('PLATINE'), LeagueDivision.platine);
      // Un serveur plus récent peut ajouter une division : la ligue reste
      // lisible plutôt que de casser l'écran.
      expect(LeagueDivision.fromApi('MITHRIL'), LeagueDivision.bronze);
    });
  });
}
