import 'dart:ui';

/// Palette Carlys.
///
/// Source de vérité : packages/design-tokens/src/tokens.json.
/// Toute nouvelle couleur doit être ajoutée aux tokens PUIS reflétée ici —
/// jamais codée en dur dans un écran.
abstract final class AppColors {
  // Marque
  static const Color primary = Color(0xFF5B5BF6);
  static const Color primaryDark = Color(0xFF4747D1);
  static const Color primaryLight = Color(0xFF8A8AFA);
  static const Color accent = Color(0xFFC6F432);
  static const Color accentDark = Color(0xFFA8D41E);

  // Neutres
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFAFAFB);
  static const Color neutral100 = Color(0xFFF4F4F6);
  static const Color neutral200 = Color(0xFFE4E4EA);
  static const Color neutral300 = Color(0xFFD1D1DA);
  static const Color neutral400 = Color(0xFFA5A5B5);
  static const Color neutral500 = Color(0xFF7A7A8C);
  static const Color neutral600 = Color(0xFF55556A);
  static const Color neutral700 = Color(0xFF3B3B4F);
  static const Color neutral800 = Color(0xFF26263A);
  static const Color neutral900 = Color(0xFF16162A);
  static const Color neutral950 = Color(0xFF0B0B18);

  // Sémantiques
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Surfaces
  static const Color lightBackground = Color(0xFFFAFAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF4F4F6);
  static const Color darkBackground = Color(0xFF0E0E1A);
  static const Color darkSurface = Color(0xFF171727);
  static const Color darkSurfaceAlt = Color(0xFF1F1F33);
  static const Color oledBackground = Color(0xFF000000);
}
