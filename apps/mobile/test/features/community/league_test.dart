import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/community/domain/entities/league.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/league_card.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/league_ladder_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : la ligue est un CHOIX, et elle se lit.
///
/// Le « périmètre choisi » du principe 5 n'est pas qu'une règle serveur : un
/// écran qui montrerait des noms d'inconnus avant l'adhésion le briserait
/// tout seul. Et un classement où l'on ne se trouve pas ne motive personne :
/// ma ligne doit être là même hors du podium.
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
    bool joined = true,
    LeagueDivision division = LeagueDivision.or,
    int score = 240,
    List<LeagueStanding>? standings,
    LeagueResult? lastResult,
  }) => League(
    joined: joined,
    periodKey: '2026-W38',
    endsAt: DateTime.now().add(const Duration(days: 3)),
    division: division,
    score: score,
    standings: standings ?? const [],
    lastResult: lastResult,
  );

  Widget carte(League league, {VoidCallback? onJoin, VoidCallback? onLeave}) =>
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: LeagueCard(
              league: league,
              onJoin: onJoin ?? () {},
              onLeave: onLeave ?? () {},
            ),
          ),
        ),
      );

  testWidgets(
    'sans adhésion, aucun nom : la carte INVITE, elle ne classe pas',
    (tester) async {
      // Un classement visible avant d'avoir dit oui briserait le « périmètre
      // CHOISI » aussi sûrement qu'une requête serveur mal filtrée.
      await tester.pumpWidget(
        carte(
          ligue(joined: false, score: 0, standings: [ligne('Boris', 400, 1)]),
        ),
      );

      expect(find.text('Rejoindre la ligue'), findsOneWidget);
      expect(find.text('Boris'), findsNothing);
      expect(find.text('Quitter la ligue'), findsNothing);
      // Ni compte à rebours : il compterait une semaine qu'on ne joue pas.
      expect(find.textContaining('J−'), findsNothing);
    },
  );

  testWidgets('rejoindre appelle l’adhésion, et une seule fois', (
    tester,
  ) async {
    var entrees = 0;
    await tester.pumpWidget(
      carte(ligue(joined: false, score: 0), onJoin: () => entrees++),
    );

    await tester.tap(find.text('Rejoindre la ligue'));
    await tester.pumpAndSettle();

    expect(entrees, 1);
  });

  testWidgets('une fois entrée, le podium se lit en POINTS', (tester) async {
    await tester.pumpWidget(
      carte(
        ligue(
          standings: [
            ligne('Boris', 480, 1),
            ligne('Chloé', 320, 2),
            ligne('Moi', 240, 3, isMe: true),
          ],
        ),
      ),
    );

    // Des points, jamais l'unité brute d'une métrique : le serveur convertit
    // avant d'additionner, sinon les mètres écraseraient les séances.
    expect(find.text('240 points cette semaine'), findsOneWidget);
    expect(find.text('480 pts'), findsOneWidget);
    expect(find.text('Toi'), findsOneWidget);
    // La division SEULE : l'en-tête de section dit déjà « Ligue », et
    // `AppSectionLabel` capitalise — on compare à CE qu'il rend.
    expect(find.text('OR'), findsOneWidget);
  });

  testWidgets('ma ligne apparaît MÊME hors du podium', (tester) async {
    await tester.pumpWidget(
      carte(
        ligue(
          score: 40,
          standings: [
            ligne('Boris', 480, 1),
            ligne('Chloé', 320, 2),
            ligne('Dan', 300, 3),
            ligne('Eva', 90, 4),
            ligne('Moi', 40, 5, isMe: true),
          ],
        ),
      ),
    );

    // Trois du podium, plus moi : cinquième, et bien là. Sans cette ligne,
    // la carte ne dirait rien à celle qui en a le plus besoin.
    expect(find.text('Toi'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Eva'), findsNothing);
  });

  testWidgets('une semaine vide le dit, au lieu de laisser un trou', (
    tester,
  ) async {
    await tester.pumpWidget(carte(ligue(score: 0)));

    expect(find.textContaining('Personne n’a encore marqué'), findsOneWidget);
  });

  testWidgets('la montée de la semaine passée s’annonce', (tester) async {
    await tester.pumpWidget(
      carte(
        ligue(
          lastResult: const LeagueResult(
            periodKey: '2026-W37',
            rank: 2,
            from: LeagueDivision.argent,
            to: LeagueDivision.or,
          ),
        ),
      ),
    );

    // Sans cette phrase, la division changerait sans explication.
    expect(find.textContaining('te voilà en Or'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
  });

  testWidgets('une descente se dit sans dramatiser', (tester) async {
    await tester.pumpWidget(
      carte(
        ligue(
          division: LeagueDivision.argent,
          lastResult: const LeagueResult(
            periodKey: '2026-W37',
            rank: 18,
            from: LeagueDivision.or,
            to: LeagueDivision.argent,
          ),
        ),
      ),
    );

    expect(find.textContaining('retour en Argent'), findsOneWidget);
    expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
  });

  testWidgets('quitter appelle la sortie', (tester) async {
    var sorties = 0;
    await tester.pumpWidget(carte(ligue(), onLeave: () => sorties++));

    await tester.ensureVisible(find.text('Quitter la ligue'));
    await tester.tap(find.text('Quitter la ligue'));
    await tester.pumpAndSettle();

    expect(sorties, 1);
  });

  group('L’échelle des divisions', () {
    testWidgets('dit à voix haute où l’on est, et sur combien', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: LeagueLadderBar(division: LeagueDivision.platine),
          ),
        ),
      );

      // L'échelle est un dessin : sans sémantique, elle ne dit rien à qui
      // n'y voit pas.
      expect(
        find.bySemanticsLabel('Division Platine, 4 sur 5'),
        findsOneWidget,
      );
    });

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
