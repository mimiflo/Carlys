/// Échelle d'espacement Carlys (tokens : spacing.*), en points logiques.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Refonte : gouttière d'écran et gaps récurrents
  static const double gutter = 22;
  static const double gapTile = 10;
  static const double gapRow = 14;
  static const double gapSection = 26;
  static const double xxxl = 64;

  /// Cible tactile MINIMALE de tout ce qui se presse (token
  /// `spacing.touchTarget`). L'ornement peut être plus petit (une flèche de
  /// 16, un disque de 40) ; la zone qui répond au doigt, jamais : elle
  /// s'élargit autour de lui. C'est la SEULE constante de cible tactile de
  /// l'application, un widget n'en déclare pas de rivale.
  static const double touchTarget = 48;

  /// Padding intérieur d'une carte secondaire (récompense vedette, axes,
  /// manifeste). Entre [md] et [lg] : à 16 la carte serre, à 24 elle se
  /// confond avec la carte de titre.
  static const double padCard = 18;
}
