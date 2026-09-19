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

class League {
  const League({
    required this.joined,
    required this.periodKey,
    required this.endsAt,
    required this.division,
    required this.score,
    required this.standings,
    this.lastResult,
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
