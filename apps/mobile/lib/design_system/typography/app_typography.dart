import 'package:flutter/material.dart';

/// Échelle typographique Carlys (tokens : typography.*).
///
/// Pas de famille de police imposée tant que les fontes ne sont pas
/// embarquées dans assets/fonts — on s'appuie sur la fonte système.
abstract final class AppTypography {
  static const TextStyle display = TextStyle(
    fontSize: 40,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 32,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
  );

  static const TextStyle title = TextStyle(
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  /// Chiffres à chasse fixe pour les métriques (charges, répétitions, minuteur).
  static const TextStyle metric = TextStyle(
    fontSize: 32,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextTheme textTheme(Color color, Color mutedColor) {
    return TextTheme(
      displayLarge: display.copyWith(color: color),
      headlineLarge: headline.copyWith(color: color),
      headlineMedium: title.copyWith(color: color),
      titleLarge: subtitle.copyWith(color: color),
      bodyLarge: bodyLarge.copyWith(color: color),
      bodyMedium: body.copyWith(color: color),
      bodySmall: body.copyWith(color: mutedColor),
      labelLarge: label.copyWith(color: color),
      labelMedium: label.copyWith(color: mutedColor),
    );
  }
}
