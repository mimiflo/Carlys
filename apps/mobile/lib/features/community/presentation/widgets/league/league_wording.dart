/// CE QUE LA CARTE DE LIGUE DIT, en fonctions pures.
///
/// La maquette écrivait « Encore 260 points pour passer Argent » sur une
/// jauge « 240 / 500 pts ». Aucun seuil de ce genre n'existe : la montée se
/// joue au RANG (les premiers de la semaine montent, s'il y a assez de
/// joueurs). Ce fichier écrit donc la seule cible réelle — l'écart avec la
/// dernière place qui monte, calculé par le serveur — et dit toujours sur
/// quoi porte la jauge (`docs/product/progression.md`, test de l'unité).
library;

import '../../../../../core/utilities/formatting.dart';
import '../../../domain/entities/league.dart';

/// La division au-dessus, ou `null` en Diamant.
LeagueDivision? nextDivisionOf(LeagueDivision division) {
  final next = division.rung + 1;
  return next < LeagueDivision.values.length
      ? LeagueDivision.values[next]
      : null;
}

/// La ligne d'état de la carte, et sa jauge éventuelle.
class LeagueProgressView {
  const LeagueProgressView({
    required this.status,
    this.gauge,
    this.gaugeLabel,
    this.gaugeSpoken,
    this.caption,
  });

  /// La phrase sous le titre.
  final String status;

  /// Remplissage de la jauge, de 0 à 1 ; `null` : pas de jauge.
  final double? gauge;

  /// Ce que la jauge mesure, à sa droite (« 240 / 275 pts »).
  final String? gaugeLabel;

  /// La même mesure, et sa base, pour le lecteur d'écran : « 240 / 275 pts »
  /// se lirait « barre oblique », et « pts » lettre à lettre.
  final String? gaugeSpoken;

  /// La base de la jauge, dite en mots sous elle, quand le libellé ne suffit
  /// pas à la nommer.
  final String? caption;
}

String _points(int value) =>
    '${formatThousands(value)} ${value <= 1 ? 'point' : 'points'}';

/// Où j'en suis cette semaine, dans l'ordre où ça compte.
///
///  1. Rien de calculé (serveur plus ancien) : le score seul, sans promesse.
///  2. Diamant : il n'y a plus de zone de montée.
///  3. Pas assez de joueurs : la semaine ne comptera pas — le dire avant
///     toute cible, sinon on pousserait à courir après une montée qui n'aura
///     pas lieu.
///  4. Dans la zone.
///  5. L'écart avec la zone, et la jauge qui le mesure.
LeagueProgressView leagueProgressOf(League league) {
  final promotion = league.promotion;
  if (promotion == null) {
    return LeagueProgressView(status: '${_points(league.score)} cette semaine');
  }

  final next = nextDivisionOf(league.division);
  if (promotion.topDivision || next == null) {
    return const LeagueProgressView(
      status: 'Tu es au sommet des ligues : il ne reste qu’à tenir ta place.',
    );
  }

  final top = promotion.promotedCount;
  if (promotion.activePlayers < promotion.minPlayers) {
    return LeagueProgressView(
      status:
          'La semaine comptera à partir de ${promotion.minPlayers} joueurs '
          'actifs.',
      gauge: promotion.activePlayers / promotion.minPlayers,
      gaugeLabel:
          '${promotion.activePlayers} / ${promotion.minPlayers} '
          'joueurs',
      gaugeSpoken:
          '${promotion.activePlayers} joueurs actifs sur '
          '${promotion.minPlayers}',
    );
  }

  if (promotion.inZone) {
    return LeagueProgressView(
      // « La zone », pas « tu montes » : un ex æquo à la frontière peut
      // laisser quelqu'un du top en place au règlement (`inZone` dit le
      // rang, pas le verdict — voir `LeaguePromotion.inZone`).
      status:
          'Tu es dans le top $top, la zone de montée vers '
          '${next.label}.',
      gauge: 1,
      gaugeLabel: 'Top $top',
      gaugeSpoken: 'Dans le top $top',
    );
  }

  final zone = promotion.zoneScore;
  return LeagueProgressView(
    status:
        'Encore ${_points(promotion.pointsToZone)} pour entrer dans le '
        'top $top.',
    gauge: zone == null || zone == 0 ? null : league.score / zone,
    gaugeLabel: zone == null
        ? null
        : '${formatThousands(league.score)} / ${formatThousands(zone)} pts',
    // La base se dit dans la même phrase : « pts » se lirait lettre à
    // lettre.
    gaugeSpoken: zone == null
        ? null
        : '${_points(league.score)} sur ${formatThousands(zone)}, le score '
              'du ${top}e aujourd’hui',
    caption: zone == null
        ? null
        : '${formatThousands(zone)} pts : le score du ${top}e aujourd’hui',
  );
}

/// Le compte à rebours de la semaine : « J-2 », ou « Dernier jour ».
String leagueCountdown(League league) =>
    league.daysLeft <= 0 ? 'Dernier jour' : 'J-${league.daysLeft}';
