/// Les cinq réponses du bilan à « Comment c'était ? », chacune posée sur
/// l'échelle de Borg CR10 (0 à 10, enregistrée de 1 à 10).
///
/// Cinq mots plutôt que dix chiffres : en fin de séance, on sait dire
/// « difficile », rarement « 7 ». La valeur de Borg reste ce qu'on stocke,
/// donc une autre échelle d'affichage ne perdrait rien.
enum EffortChoice {
  veryEasy('Très facile', 2),
  easy('Facile', 4),
  moderate('Modéré', 5),
  hard('Difficile', 7),
  allOut('À fond', 9);

  const EffortChoice(this.label, this.borg);

  final String label;
  final int borg;

  /// La réponse qui représente [value] — la base peut tenir n'importe quel
  /// entier de 1 à 10 (autre client, saisie future plus fine). Les bandes
  /// suivent celles du repos conseillé : ≤ 4, 5–6, ≥ 7.
  static EffortChoice? fromBorg(int? value) => switch (value) {
    null => null,
    <= 2 => veryEasy,
    <= 4 => easy,
    <= 6 => moderate,
    <= 8 => hard,
    _ => allOut,
  };
}
