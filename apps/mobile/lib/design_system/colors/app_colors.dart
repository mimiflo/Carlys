import 'package:flutter/material.dart';

/// Palette Carlys — refonte « premium dark-first ».
///
/// Source de vérité : packages/design-tokens/src/tokens.json.
/// Toute nouvelle couleur doit être ajoutée aux tokens PUIS reflétée ici —
/// jamais codée en dur dans un écran.
///
/// Règles d'usage (handoff/README.md) :
///  - l'accent lime ne sert qu'à UNE action ou métrique clé par écran ;
///  - le violet porte l'atmosphère (halos, gradients, scènes 3D), pas les
///    boutons ;
///  - aucune ombre portée sur les cartes.
abstract final class AppColors {
  // Marque
  static const Color primary = Color(0xFF5B5BF6);
  static const Color primaryDark = Color(0xFF4747D1);
  static const Color primaryLight = Color(0xFF8A8AFA);
  static const Color accent = Color(0xFFC6F432);

  // ── Dégradé de MARQUE ────────────────────────────────────────────
  //
  // Relevé sur le logo Carlys. Réservé aux surfaces de marque (page de
  // bienvenue, logo) : il ne remplace jamais `primary`/`accent`, qui restent
  // les couleurs de l'application. Les mélanger diluerait les deux.
  static const Color signatureStart = Color(0xFF7B4BF6);
  static const Color signatureMid = Color(0xFFCD2EDA);
  static const Color signatureEnd = Color(0xFFF7708F);

  /// Dégradé de marque, de gauche à droite.
  static const LinearGradient signature = LinearGradient(
    colors: [signatureStart, signatureMid, signatureEnd],
  );
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
  static const Color logout = Color(0xFFFF6B6B);

  // Surfaces — thème sombre de RÉFÉRENCE (dark-first)
  static const Color darkBackground = Color(0xFF06060C);
  static const Color darkSurface = Color(0xFF101019);
  static const Color darkSurfaceAlt = Color(0xFF16161F);

  /// Cartes posées sur une scène 3D uniquement (avec BackdropFilter blur 24).
  static const Color darkGlass = Color(0xB8101019);

  // Rôles de texte et traits du thème sombre
  static const Color darkTextPrimary = Color(0xFFF2F2F6);
  static const Color darkTextSecondary = Color(0xFF9A9AAE);
  static const Color darkTextTertiary = Color(0xFF7A7A8C);
  static const Color darkIconInactive = Color(0xFF6A6A7E);
  static const Color darkBorder = Color(0x12FFFFFF);
  static const Color darkBorderStrong = Color(0x24FFFFFF);

  /// Trou central de l'anneau de forme.
  static const Color ringHole = Color(0xFF0C0C15);

  // Surfaces — thème clair (secondaire) et OLED
  static const Color lightBackground = Color(0xFFFAFAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF4F4F6);
  static const Color oledBackground = Color(0xFF000000);

  // Teintes dérivées récurrentes (handoff/design-tokens.md)
  static const Color primaryHalo = Color(0x4D5B5BF6); // primary .30
  static const Color primaryCardStrong = Color(0x475B5BF6); // primary .28
  static const Color primaryCardSoft = Color(0x0D5B5BF6); // primary .05
  static const Color primaryFill = Color(0x735B5BF6); // primary .45
  static const Color accentBadgeBg = Color(0x1FC6F432); // accent .12
  static const Color accentBadgeBorder = Color(0x47C6F432); // accent .28
  static const Color neutralBadgeBg = Color(0x12FFFFFF); // blanc .07
  static const Color neutralBadgeText = Color(0xFFD3D3E4);
  static const Color gaugeTrack = Color(0x12FFFFFF); // blanc .07
  static const Color primaryLightBorder = Color(0x4D8A8AFA); // primaryLight .30
  static const Color difficultyTrack = Color(0x1FFFFFFF); // blanc .12
  static const Color vignetteBorder = Color(0x388A8AFA); // primaryLight .22
  static const Color rowDivider = Color(0x0FFFFFFF); // blanc .06
  static const Color heatEmpty = Color(0x0DFFFFFF); // blanc .05
  static const Color heatOutOfMonth = Color(0x08FFFFFF); // blanc .03

  /// Remplissage d'un jour du calendrier selon l'intensité 0..1 (violet).
  static Color heatFill(double intensity) => Color.lerp(
        const Color(0x805B5BF6),
        const Color(0xE65B5BF6),
        intensity.clamp(0, 1),
      )!;
}
