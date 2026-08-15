/// Les CINQ VALEURS de Carlys, et le manifeste dont elles découlent.
///
/// Elles ne sont pas décoratives et ne vivent pas dans une seule
/// fonctionnalité : elles ordonnent la rotation des maximes du jour, elles
/// donnent ses axes au profil de progression, et elles fixent le vocabulaire
/// commun d'un écran à l'autre. D'où leur place dans `core/` plutôt que dans
/// un dossier de fonctionnalité : les y enfermer obligerait la progression à
/// dépendre du tableau de bord, ou pire, à s'en recopier une deuxième liste.
library;

/// Ce que Carlys mesure et défend, dans l'ordre du manifeste.
///
/// Chaque valeur répond à une question simple, et l'application sait
/// répondre à cette question avec des faits qu'elle possède déjà : c'est ce
/// qui rend la progression honnête plutôt que décorative.
enum CarlysValue {
  /// Reviens-tu ? Le fait mesuré est la RÉGULARITÉ des séances.
  constance(
    'Constance',
    'Revenir, semaine après semaine.',
  ),

  /// Comprends-tu ce que tu fais ? Le fait mesuré est l'ACADEMY.
  maitrise(
    'Maîtrise',
    'Comprendre le pourquoi avant le combien.',
  ),

  /// Progresses-tu ? Le fait mesuré est la CHARGE réellement soulevée.
  performance(
    'Performance',
    'Demander un peu plus, régulièrement.',
  ),

  /// Tiens-tu ce que tu as prévu ? Le fait mesuré est le respect des
  /// SÉANCES PRÉVUES, terminées plutôt qu'abandonnées.
  discipline(
    'Discipline',
    'Tenir le rendez-vous, même au format court.',
  ),

  /// Récupères-tu ? Le fait mesuré est le REPOS et le suivi du corps.
  equilibre(
    'Équilibre',
    'Récupérer fait partie de l’entraînement.',
  );

  const CarlysValue(this.label, this.promise);

  /// Libellé affiché, accentué.
  final String label;

  /// Ce que la valeur demande, en une phrase. Jamais un ordre : Carlys
  /// accompagne sans juger.
  final String promise;
}
