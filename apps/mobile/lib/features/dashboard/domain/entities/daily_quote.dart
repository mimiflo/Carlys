/// Les cinq valeurs de Carlys, et la maxime du jour qui en porte une.
library;

/// Ce que Carlys défend, dans l'ordre où l'app le fait vivre.
///
/// Ces valeurs ne sont pas décoratives : elles ordonnent la rotation des
/// maximes (une valeur différente chaque jour) et donnent au produit un
/// discours cohérent d'un écran à l'autre.
enum CarlysValue {
  /// Aller chercher la répétition d'après.
  depassement('Dépassement'),

  /// Comprendre ce qu'on fait, et pourquoi.
  connaissance('Connaissance'),

  /// La qualité du mouvement avant la charge.
  maitrise('Maîtrise'),

  /// Ce qu'on répète devient ce qu'on est.
  constance('Constance'),

  /// Le repos et la nutrition font partie de l'entraînement.
  equilibre('Équilibre');

  const CarlysValue(this.label);

  /// Libellé affiché, accentué.
  final String label;
}

/// Maxime du jour : une phrase, la valeur qu'elle sert.
class DailyQuote {
  const DailyQuote({required this.text, required this.value});

  final String text;
  final CarlysValue value;
}
