/// Fréquence des interventions du Mentor sur l'accueil.
///
/// Deux crans seulement : le Mentor est un repère, pas un flux. « Jamais »
/// n'est pas une fréquence — c'est la bascule d'activation qui le dit.
enum MentorFrequency {
  hebdomadaire('semaine', 'Hebdomadaire'),
  quotidienne('jour', 'Quotidienne');

  const MentorFrequency(this.wire, this.label);

  /// Valeur rangée dans les préférences locales.
  final String wire;
  final String label;

  static MentorFrequency fromWire(String? wire) {
    for (final frequency in values) {
      if (frequency.wire == wire) {
        return frequency;
      }
    }
    // Valeur absente ou inconnue : le cran DISCRET, jamais le plus bavard.
    return MentorFrequency.hebdomadaire;
  }
}

/// Préférences d'INTERVENTION du Mentor — locales à l'appareil, comme tout
/// réglage d'affichage : elles disent quand le Mentor parle ICI, pas qui
/// il est (sa voix, elle, vit sur le profil serveur).
class MentorPrefs {
  const MentorPrefs({
    required this.interventionsActives,
    required this.frequence,
    this.voixParlee = true,
  });

  /// Activées par défaut : même règle que les catégories de notification,
  /// « jamais réglé vaut accepté » — et la fréquence par défaut est le cran
  /// discret.
  static const MentorPrefs defauts = MentorPrefs(
    interventionsActives: true,
    frequence: MentorFrequency.hebdomadaire,
  );

  final bool interventionsActives;
  final MentorFrequency frequence;

  /// Le Mentor dit son mot À VOIX HAUTE quand on ouvre sa feuille. Coupé,
  /// il ne parle plus que sur demande (le bouton « Écouter »). Actif par
  /// défaut : une voix qu'on a choisie et qu'on n'entend jamais ne sert à
  /// rien.
  final bool voixParlee;
}
