/// Seuils des classes de taille de fenêtre (tokens : breakpoint.*), alignés
/// sur les window size classes Material 3.
abstract final class AppBreakpoints {
  /// La classe la plus étroite commence à zéro, comme dans `tokens.json` :
  /// un jeton sans reflet ici serait une moitié de pont, et le test qui
  /// garde ce pont le dirait.
  static const double compact = 0;
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
  static const double xlarge = 1600;
}
