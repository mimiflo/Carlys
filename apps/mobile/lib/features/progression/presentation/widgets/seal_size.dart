/// Les deux seules tailles du sceau, et le seuil qui les sépare.
///
/// Elles vivent à part parce que les DEUX faces du sceau en dépendent : le
/// widget y règle sa typographie et la taille de son glyphe, le peintre
/// l'épaisseur de son filet et la présence des ornements internes. Portées
/// par l'un des deux, elles obligeaient l'autre à l'importer en retour ; et
/// deux fichiers qui s'importent mutuellement ne se lisent plus, ni ne se
/// déplacent, séparément.
///
/// Deux tailles seulement. À [small], les ornements internes disparaissent :
/// la silhouette suffit, et un détail de deux pixels n'est plus qu'une
/// salissure.
abstract final class SealSize {
  /// Vitrine et bloc compact.
  static const double large = 56;

  /// Ligne de liste.
  static const double small = 34;

  /// Sceau frappé à pleine taille, ornements compris.
  ///
  /// C'est ce SEUIL, et non la valeur exacte, que le widget et le peintre
  /// interrogent chacun de leur côté : il s'écrit donc une fois.
  static bool isLarge(double size) => size >= large;
}
