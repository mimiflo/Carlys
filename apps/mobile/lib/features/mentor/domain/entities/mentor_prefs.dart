/// Fréquence des interventions du Mentor sur l'accueil.
///
/// Deux crans seulement : le Mentor est un repère, pas un flux. « Jamais »
/// n'est pas une fréquence — c'est la bascule d'activation qui le dit.
enum MentorFrequency {
  hebdomadaire('semaine', 'Chaque semaine'),
  quotidienne('jour', 'Chaque jour');

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
}
