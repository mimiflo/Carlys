import 'package:flutter/material.dart';

/// Échelle typographique Carlys — refonte (tokens : typography.scale).
///
/// Deux familles seulement : Inter (texte) et JetBrains Mono (TOUS les
/// chiffres, en chiffres tabulaires — sans ça les compteurs sautent
/// pendant les animations).
abstract final class AppTypography {
  static const String textFamily = 'Inter';
  static const String monoFamily = 'JetBrainsMono';

  // ── Texte (Inter) ────────────────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontFamily: textFamily,
    fontSize: 30,
    height: 1.05,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
  );

  static const TextStyle title = TextStyle(
    fontFamily: textFamily,
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.44,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: textFamily,
    fontSize: 17,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.17,
  );

  static const TextStyle subheading = TextStyle(
    fontFamily: textFamily,
    fontSize: 15,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  );

  static const TextStyle body = TextStyle(
    fontFamily: textFamily,
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label = TextStyle(
    fontFamily: textFamily,
    fontSize: 12,
    height: 1.0,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle tab = TextStyle(
    fontFamily: textFamily,
    fontSize: 9,
    height: 1.0,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle tabActive = TextStyle(
    fontFamily: textFamily,
    fontSize: 9,
    height: 1.0,
    fontWeight: FontWeight.w600,
  );

  // ── Métriques (JetBrains Mono, chiffres tabulaires) ──────────────
  static const TextStyle metricXL = TextStyle(
    fontFamily: monoFamily,
    fontSize: 46,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.84,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricL = TextStyle(
    fontFamily: monoFamily,
    fontSize: 26,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.52,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricM = TextStyle(
    fontFamily: monoFamily,
    fontSize: 19,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.38,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricS = TextStyle(
    fontFamily: monoFamily,
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Toujours en MAJUSCULES. `primaryLight` quand il introduit une section,
  /// `textTertiary` quand il légende une valeur.
  static const TextStyle labelMono = TextStyle(
    fontFamily: monoFamily,
    fontSize: 10,
    height: 1.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ── Alias de compatibilité (anciens noms encore référencés) ──────
  static const TextStyle headline = title;
  static const TextStyle subtitle = heading;
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: textFamily,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle metric = metricL;

  static TextTheme textTheme(Color color, Color mutedColor) {
    return TextTheme(
      displayLarge: display.copyWith(color: color),
      headlineLarge: display.copyWith(color: color),
      headlineMedium: title.copyWith(color: color),
      titleLarge: heading.copyWith(color: color),
      titleMedium: subheading.copyWith(color: color),
      bodyLarge: bodyLarge.copyWith(color: color),
      bodyMedium: body.copyWith(color: color),
      bodySmall: body.copyWith(color: mutedColor),
      labelLarge: label.copyWith(color: color),
      labelMedium: label.copyWith(color: mutedColor),
      labelSmall: labelMono.copyWith(color: mutedColor),
    );
  }
}
