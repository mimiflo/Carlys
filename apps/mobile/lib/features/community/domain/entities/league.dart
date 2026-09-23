/// LA LIGUE : un classement hebdomadaire, CHOISI, qui ne rend rien au profil.
///
/// Trois garanties la tiennent à distance du titre Carlys, et elles se lisent
/// dans ce fichier : on n'y entre qu'en le demandant ([League.joined]), la
/// fenêtre se ferme chaque semaine ([League.periodKey]), et rien de ce qu'elle
/// montre n'alimente un axe ni une récompense. Barème complet :
/// `docs/product/community.md`, « Les ligues, barème complet ».
library;

/// Les cinq divisions, de la plus basse à la plus haute. L'ORDRE est le
/// barème : c'est lui qui dessine l'échelle à l'écran.
enum LeagueDivision {
  bronze('BRONZE', 'Bronze'),
  argent('ARGENT', 'Argent'),
  or('OR', 'Or'),
  platine('PLATINE', 'Platine'),
  diamant('DIAMANT', 'Diamant');

  const LeagueDivision(this.apiValue, this.label);

  final String apiValue;

  /// Ce que la personne LIT.
  final String label;

  /// Position sur l'échelle, de 0 (Bronze) à 4 (Diamant).
  int get rung => index;

  static LeagueDivision fromApi(String? value) {
    for (final division in LeagueDivision.values) {
      if (division.apiValue == value) {
        return division;
      }
    }
    // Un serveur plus récent peut ajouter une division : la ligue reste
    // lisible, on la montre au plus bas plutôt que de casser l'écran.
    return LeagueDivision.bronze;
  }
}

/// Une ligne du classement : qui, combien, et à quelle place.
class LeagueStanding {
  const LeagueStanding({
    required this.userId,
    required this.displayName,
    required this.score,
    required this.rank,
    required this.isMe,
  });

  final String userId;
  final String displayName;

  /// Des POINTS, jamais l'unité brute d'une métrique : le serveur convertit
  /// avant d'additionner, sans quoi les mètres écraseraient les séances.
  final int score;
  final int rank;
  final bool isMe;
}

/// Le résultat de la période précédente, annoncé UNE fois.
class LeagueResult {
  const LeagueResult({
    required this.periodKey,
    required this.rank,
    required this.from,
    required this.to,
  });

  final String periodKey;
  final int rank;
  final LeagueDivision from;
  final LeagueDivision to;

  bool get isPromotion => to.rung > from.rung;
  bool get isRelegation => to.rung < from.rung;
}

/// OÙ J'EN SUIS face à la zone de montée, si la semaine se fermait
/// maintenant.
///
/// Calculé par le SERVEUR, à côté du règlement et avec sa règle
/// (`league-ladder.ts`, `promotionOutlook`) : l'appli ÉCRIT ces nombres, elle
/// ne les calcule jamais. Une copie de la règle ici divergerait exactement
/// sur l'ex æquo à la frontière, et à la première retouche du barème.
///
/// La montée se joue au RANG, pas à un seuil de points : [pointsToZone] dit
/// l'écart avec la 5e place, qui BOUGE avec les autres.
class LeaguePromotion {
  const LeaguePromotion({
    required this.promotedCount,
    required this.minPlayers,
    required this.activePlayers,
    required this.topDivision,
    required this.inZone,
    required this.zoneScore,
    required this.pointsToZone,
  });

  /// Combien montent au règlement — servi pour être écrit, jamais recopié.
  final int promotedCount;

  /// En dessous de ce nombre de joueurs à score non nul, personne ne bouge.
  final int minPlayers;

  /// Membres de ma division qui ont marqué cette semaine, moi compris. Face
  /// à [minPlayers], il dit si la semaine COMPTERA — ce que [inZone] ne dit
  /// volontairement pas.
  final int activePlayers;

  /// Vrai en Diamant : rien au-dessus, donc ni zone ni écart.
  final bool topDivision;

  /// Je monterais si la semaine se fermait maintenant, au sens du RANG seul :
  /// ni le minimum de joueurs ni les ex æquo à cheval sur les deux moitiés
  /// n'y entrent. C'est la zone, pas le verdict. Toujours faux en Diamant.
  final bool inZone;

  /// Le score à ÉGALER pour entrer dans la zone (les ex æquo partagent le
  /// rang). `null` quand un point suffit — moins de [promotedCount] autres
  /// ont marqué — et en Diamant.
  final int? zoneScore;

  /// Points qui me manquent pour entrer dans la zone ; 0 dedans et en
  /// Diamant.
  final int pointsToZone;
}

class League {
  const League({
    required this.joined,
    required this.periodKey,
    required this.endsAt,
    required this.division,
    required this.score,
    required this.standings,
    this.lastResult,
    this.promotion,
  });

  /// Faux tant qu'on n'a pas rejoint : le classement est alors VIDE, et
  /// l'écran montre l'invitation à entrer plutôt que des noms d'inconnus.
  final bool joined;

  /// Semaine ISO en UTC, `YYYY-Www`. Une chaîne, parce qu'une période est un
  /// fait civil : un instant se décalerait d'un fuseau à l'autre.
  final String periodKey;
  final DateTime endsAt;
  final LeagueDivision division;
  final int score;
  final List<LeagueStanding> standings;
  final LeagueResult? lastResult;

  /// Où j'en suis face à la zone de montée. `null` sans adhésion (il n'y a
  /// ni classement ni zone), ou face à un serveur qui ne le sert pas encore.
  final LeaguePromotion? promotion;

  /// Ma ligne du classement, s'il y en a une.
  LeagueStanding? get me {
    for (final standing in standings) {
      if (standing.isMe) {
        return standing;
      }
    }
    return null;
  }

  /// Jours restants avant la fermeture, jamais négatif.
  int get daysLeft {
    final reste = endsAt.difference(DateTime.now()).inDays;
    return reste < 0 ? 0 : reste;
  }
}
