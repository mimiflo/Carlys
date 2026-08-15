import 'package:flutter/material.dart';

/// Échelle typographique Carlys — refonte (tokens : typography.scale).
///
/// Trois familles, chacune avec un rôle exclusif : Inter (texte), JetBrains
/// Mono (TOUS les chiffres, en chiffres tabulaires — sans ça les compteurs
/// sautent pendant les animations), et Oswald pour la seule maxime du jour.
abstract final class AppTypography {
  static const String textFamily = 'Inter';
  static const String monoFamily = 'JetBrainsMono';

  /// Familles de SECOURS, essayées dans l'ordre pour les signes que nos
  /// polices ne dessinent pas — les emoji au premier chef.
  ///
  /// Inter, JetBrains Mono et Oswald n'embarquent aucun emoji. Quand une
  /// famille est imposée par `fontFamily`, le moteur n'a nulle part où se
  /// rabattre : le signe manquant s'affiche en carré vide. Un ami qui
  /// envoie « Belle série ! 💪 » voyait donc son emoji remplacé par un
  /// tofu. Ces trois familles sont les polices emoji du système (iOS et
  /// macOS, Android et Linux, Windows) : celle de l'appareil répond, les
  /// autres sont simplement ignorées.
  static const List<String> emojiFallback = <String>[
    'Apple Color Emoji',
    'Noto Color Emoji',
    'Segoe UI Emoji',
  ];

  /// Famille d'AFFICHE, réservée à la maxime du jour.
  ///
  /// Oswald est la grotesque condensée des affiches de salle et des dossards :
  /// elle porte une phrase courte avec une autorité qu'Inter, neutre par
  /// vocation, n'a pas. Condensée, elle loge aussi plus de signes par ligne,
  /// donc la citation s'affiche plus grande à surface égale.
  ///
  /// **Un seul usage** : l'étendre à d'autres écrans dissoudrait l'effet et
  /// brouillerait la hiérarchie — Inter reste la voix de l'application.
  static const String quoteFamily = 'Oswald';

  // ── Texte (Inter) ────────────────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontFamily: textFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 30,
    height: 1.05,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
  );

  static const TextStyle title = TextStyle(
    fontFamily: textFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.44,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: textFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 17,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.17,
  );

  static const TextStyle subheading = TextStyle(
    fontFamily: textFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 15,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  );

  static const TextStyle body = TextStyle(
    fontFamily: textFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label = TextStyle(
    fontFamily: textFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 12,
    height: 1.0,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle tab = TextStyle(
    fontFamily: textFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 9,
    height: 1.0,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle tabActive = TextStyle(
    fontFamily: textFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 9,
    height: 1.0,
    fontWeight: FontWeight.w600,
  );

  // ── Métriques (JetBrains Mono, chiffres tabulaires) ──────────────
  static const TextStyle metricXL = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 46,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.84,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricL = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 26,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.52,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricM = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 19,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.38,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricS = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Toujours en MAJUSCULES. `primaryLight` quand il introduit une section,
  /// `textTertiary` quand il légende une valeur.
  /// Maxime du jour. Le corps est choisi à l'affichage par [AppFittedText] :
  /// celui-ci n'est qu'un point de départ.
  static const TextStyle quote = TextStyle(
    fontFamily: quoteFamily,
    fontFamilyFallback: emojiFallback,
    fontSize: 24,
    height: 1.22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle labelMono = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: emojiFallback,
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
    fontFamilyFallback: emojiFallback,
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
