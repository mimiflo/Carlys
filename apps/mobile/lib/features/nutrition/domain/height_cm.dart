import 'dart:math' as math;

/// La TAILLE en centimètres : ses bornes, sa précision, son écriture.
///
/// Sorti du formulaire, où ces règles étaient mêlées à la construction des
/// widgets. Elles n'en sont pas : ce sont des règles de domaine, elles
/// doivent le même résultat au serveur, et elles se testent sans ouvrir
/// d'écran.
///
/// Les trois bornes sont celles du contrat publié
/// (`packages/api-contracts/src/users.ts` : `HEIGHT_CM_MIN`, `HEIGHT_CM_MAX`,
/// `HEIGHT_CM_DECIMALS`), que le DTO applique côté API. La précision
/// manquait ici : une saisie « 175,25 » passait la validation locale pour se
/// faire refuser par le serveur, et l'écran n'avait rien de plus précis à
/// dire qu'un message générique.
class HeightCm {
  const HeightCm._();

  static const double min = 80;
  static const double max = 250;
  static const int decimals = 1;

  /// Lit une saisie française ou anglaise (« 175,5 » comme « 175.5 »).
  /// `null` si le champ est vide ou illisible — l'appelant distingue les deux.
  static double? parse(String raw) {
    final nettoye = raw.trim().replaceFirst(',', '.');
    return nettoye.isEmpty ? null : double.tryParse(nettoye);
  }

  /// Écriture destinée au champ : sans décimale quand elle est inutile, avec
  /// la virgule française sinon.
  static String format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(decimals).replaceFirst('.', ',');

  /// La valeur tient-elle sur le nombre de décimales autorisé ?
  ///
  /// Le contrôle porte sur la valeur ARRONDIE, jamais sur l'écriture
  /// décimale : `175.1` n'est pas représentable exactement en binaire, et
  /// comparer des chaînes refuserait une saisie parfaitement légitime.
  static bool hasAllowedPrecision(double value) {
    final echelle = value * math.pow(10, decimals);
    return (echelle - echelle.roundToDouble()).abs() < 1e-9;
  }

  /// Le message à afficher sous le champ, ou `null` si la saisie convient.
  /// Un champ VIDE convient : la taille est facultative, et le serveur liste
  /// lui-même ce qui lui manque.
  static String? validationError(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final valeur = parse(raw);
    if (valeur == null || valeur < min || valeur > max) {
      return 'Taille entre ${min.round()} et ${max.round()} cm';
    }
    if (!hasAllowedPrecision(valeur)) {
      return 'Une seule décimale (par exemple 175,5)';
    }
    return null;
  }
}
