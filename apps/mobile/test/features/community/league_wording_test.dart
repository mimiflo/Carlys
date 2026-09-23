import 'package:carlys_mobile/features/community/domain/entities/league.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/league/league_wording.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE LA CARTE DE LIGUE PROMET, cas par cas.
///
/// La maquette écrivait « Encore 260 points pour passer Argent » sur une
/// jauge « 240 / 500 pts » : un seuil qui n'existe pas. La montée se joue au
/// RANG, et la seule cible réelle est l'écart avec la dernière place qui
/// monte — calculé par le serveur. Chaque cas ci-dessous est une promesse
/// que l'écran ne doit pas trahir.
void main() {
  League ligue({
    LeagueDivision division = LeagueDivision.bronze,
    int score = 240,
    LeaguePromotion? promotion,
    Duration reste = const Duration(days: 2, hours: 6),
  }) => League(
    joined: true,
    periodKey: '2026-W39',
    endsAt: DateTime.now().add(reste),
    division: division,
    score: score,
    standings: const [],
    promotion: promotion,
  );

  LeaguePromotion montee({
    int activePlayers = 12,
    bool topDivision = false,
    bool inZone = false,
    int? zoneScore = 275,
    int pointsToZone = 35,
  }) => LeaguePromotion(
    promotedCount: 5,
    minPlayers: 10,
    activePlayers: activePlayers,
    topDivision: topDivision,
    inZone: inZone,
    zoneScore: zoneScore,
    pointsToZone: pointsToZone,
  );

  group('leagueProgressOf', () {
    test('sans calcul du serveur : le score seul, sans promesse', () {
      final vue = leagueProgressOf(ligue());

      expect(vue.status, '240 points cette semaine');
      expect(vue.gauge, isNull);
    });

    test('un seul point s’écrit au singulier', () {
      expect(leagueProgressOf(ligue(score: 1)).status, '1 point cette semaine');
    });

    test('en Diamant, il ne reste qu’à tenir sa place', () {
      final vue = leagueProgressOf(
        ligue(
          division: LeagueDivision.diamant,
          promotion: montee(topDivision: true),
        ),
      );

      expect(
        vue.status,
        'Tu es au sommet des ligues : il ne reste qu’à tenir ta place.',
      );
      // Aucune jauge : il n'y a plus de zone de montée à viser.
      expect(vue.gauge, isNull);
    });

    test('trop peu de joueurs : on le dit AVANT toute cible', () {
      // Sinon on pousserait à courir après une montée qui n'aura pas lieu.
      final vue = leagueProgressOf(ligue(promotion: montee(activePlayers: 7)));

      expect(vue.status, 'La semaine comptera à partir de 10 joueurs actifs.');
      expect(vue.gauge, closeTo(0.7, 1e-9));
      // La jauge compte des JOUEURS, et le dit.
      expect(vue.gaugeLabel, '7 / 10 joueurs');
      expect(vue.gaugeSpoken, '7 joueurs actifs sur 10');
    });

    test('un seul joueur actif se dit au singulier', () {
      final vue = leagueProgressOf(ligue(promotion: montee(activePlayers: 1)));

      expect(vue.gaugeSpoken, '1 joueur actif sur 10');
    });

    test('trop peu de joueurs l’emporte même dans la zone', () {
      final vue = leagueProgressOf(
        ligue(promotion: montee(activePlayers: 4, inZone: true)),
      );

      expect(vue.status, startsWith('La semaine comptera'));
    });

    test('dans la zone : « la zone de montée », jamais « tu montes »', () {
      // Un ex æquo à la frontière peut laisser quelqu'un du top en place au
      // règlement : `inZone` dit le rang, pas le verdict.
      final vue = leagueProgressOf(ligue(promotion: montee(inZone: true)));

      expect(vue.status, 'Tu es dans le top 5, la zone de montée vers Argent.');
      expect(vue.gauge, 1);
      expect(vue.gaugeLabel, 'Top 5');
      expect(vue.gaugeSpoken, 'Dans le top 5');
      expect(vue.status, isNot(contains('tu montes')));
    });

    test('hors de la zone : l’écart, et la jauge qui dit sa base', () {
      final vue = leagueProgressOf(ligue(promotion: montee()));

      expect(vue.status, 'Encore 35 points pour entrer dans le top 5.');
      expect(vue.gauge, closeTo(240 / 275, 1e-9));
      expect(vue.gaugeLabel, '240 / 275 pts');
      // Lue, la barre oblique se dirait « barre oblique ».
      expect(vue.gaugeSpoken, '240 points sur 275, le score du 5e aujourd’hui');
      expect(vue.caption, '275 pts : le score du 5e aujourd’hui');
    });

    test('un point d’écart s’écrit au singulier', () {
      final vue = leagueProgressOf(ligue(promotion: montee(pointsToZone: 1)));

      expect(vue.status, 'Encore 1 point pour entrer dans le top 5.');
    });

    test('les milliers se séparent', () {
      final vue = leagueProgressOf(
        ligue(
          score: 1200,
          promotion: montee(zoneScore: 1500, pointsToZone: 301),
        ),
      );

      expect(vue.gaugeLabel, '1\u202F200 / 1\u202F500 pts');
    });

    test('sans score de zone connu : l’écart seul, sans jauge inventée', () {
      final vue = leagueProgressOf(
        ligue(promotion: montee(zoneScore: null, pointsToZone: 1)),
      );

      expect(vue.status, 'Encore 1 point pour entrer dans le top 5.');
      expect(vue.gauge, isNull);
      expect(vue.gaugeLabel, isNull);
      expect(vue.gaugeSpoken, isNull);
      expect(vue.caption, isNull);
    });
  });

  group('nextDivisionOf', () {
    test('chaque division mène à la suivante, Diamant à rien', () {
      expect(nextDivisionOf(LeagueDivision.bronze), LeagueDivision.argent);
      expect(nextDivisionOf(LeagueDivision.platine), LeagueDivision.diamant);
      expect(nextDivisionOf(LeagueDivision.diamant), isNull);
    });
  });

  group('leaguePlace et leaguePoints', () {
    test('la place s’accorde à « place », jamais à la personne', () {
      expect(leaguePlace(1), '1re place');
      expect(leaguePlace(2), '2e place');
      expect(leaguePlace(18), '18e place');
    });

    test('zéro et un point au singulier', () {
      expect(leaguePoints(0), '0 point');
      expect(leaguePoints(1), '1 point');
      expect(leaguePoints(2), '2 points');
    });
  });

  group('leagueCountdownSpoken', () {
    test('accordé au nombre de jours', () {
      expect(
        leagueCountdownSpoken(ligue(reste: const Duration(days: 1, hours: 3))),
        'Encore 1 jour avant la fin de la semaine',
      );
      expect(
        leagueCountdownSpoken(ligue()),
        'Encore 2 jours avant la fin de la semaine',
      );
      expect(
        leagueCountdownSpoken(ligue(reste: const Duration(hours: 5))),
        'Dernier jour de la semaine',
      );
    });
  });

  group('leagueCountdown', () {
    test('les jours pleins qui restent', () {
      // Le signe moins, comme les cartes de défis de la même page.
      expect(leagueCountdown(ligue()), 'J\u22122');
    });

    test('le dernier jour se nomme', () {
      expect(
        leagueCountdown(ligue(reste: const Duration(hours: 5))),
        'Dernier jour',
      );
    });

    test('une semaine déjà close ne compte pas à rebours dans le négatif', () {
      expect(
        leagueCountdown(ligue(reste: const Duration(hours: -3))),
        'Dernier jour',
      );
    });
  });
}
