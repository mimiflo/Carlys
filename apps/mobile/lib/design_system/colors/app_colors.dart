import 'package:flutter/material.dart';

/// Palette Carlys — refonte « premium dark-first ».
///
/// Source de vérité : packages/design-tokens/src/tokens.json.
/// Toute nouvelle couleur doit être ajoutée aux tokens PUIS reflétée ici —
/// jamais codée en dur dans un écran.
///
/// Règles d'usage (handoff/README.md) :
///  - l'accent orange ne sert qu'à UNE action ou métrique clé par écran ;
///  - le violet porte l'atmosphère (halos, gradients, scènes 3D), pas les
///    boutons ;
///  - le magenta n'existe QUE comme transition de dégradé, jamais à plat :
///    posé seul, c'est lui qui fait basculer l'écran du côté « rose » ;
///  - aucune ombre portée sur les cartes.
abstract final class AppColors {
  // Marque — violet électrique
  static const Color primary = Color(0xFF9B30FF);
  static const Color primaryDark = Color(0xFF7B1FFF);
  static const Color primaryLight = Color(0xFFC88BFF);

  /// Extrémité claire du dégradé violet. Surfaces sans texte uniquement
  /// (blanc dessus : 3.86, sous le seuil AA).
  static const Color primaryFlash = Color(0xFFB44DFF);

  /// Accent unique de l'application : chaud, lisible sur le fond sombre
  /// (7.82) comme sous du texte noir (8.12).
  static const Color accent = Color(0xFFFF7A45);
  static const Color accentDark = Color(0xFFE85F2A);

  /// Charnière entre le violet et l'orange. **Jamais utilisée à plat** — voir
  /// la règle d'usage en tête de classe.
  static const Color magenta = Color(0xFFED35A9);

  /// Dégradé d'ambiance : ce qui remplit (jauges, halos) plutôt que ce qui
  /// se lit. Il s'éclaircit dans le sens de la progression.
  static const LinearGradient violetRamp = LinearGradient(
    colors: [primaryDark, primaryFlash],
  );

  /// Même dégradé, pour ce qui monte plutôt que ce qui avance.
  static const LinearGradient violetRampUp = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [primaryDark, primaryFlash],
  );

  /// Dégradé d'énergie, du violet à l'orange en passant par le magenta.
  /// Rare par construction : un seul point d'écran, sinon il perd son éclat.
  static const LinearGradient energy = LinearGradient(
    colors: [primary, magenta, accent],
  );

  // ── Dégradé de MARQUE ────────────────────────────────────────────
  //
  // Relevé sur le logo Carlys. Réservé aux surfaces de marque (page de
  // bienvenue, logo) : il ne remplace jamais `primary`/`accent`, qui restent
  // les couleurs de l'application. Les mélanger diluerait les deux.
  static const Color signatureStart = primaryDark;
  static const Color signatureMid = Color(0xFFC42EE0);
  static const Color signatureEnd = Color(0xFFFF7A45);

  /// Dégradé de marque, de gauche à droite.
  ///
  /// Les arrêts sont explicites : à parts égales, le magenta central occupe
  /// la moitié de la course et l'orange n'apparaît que dans les tout derniers
  /// pixels — mesuré sur le bouton de bienvenue, il n'y arrivait jamais. Le
  /// violet tient la première moitié, l'orange le dernier dixième en aplat.
  static const LinearGradient signature = LinearGradient(
    colors: [signatureStart, signatureMid, signatureEnd],
    stops: [0, 0.45, 0.9],
  );

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
  //
  // Teintées de violet plutôt que neutres : un fond gris sous un violet
  // électrique le fait paraître sale ; le même violet sur un fond qui en
  // porte la trace ressort.
  static const Color darkBackground = Color(0xFF08050E);
  static const Color darkSurface = Color(0xFF15101F);
  static const Color darkSurfaceAlt = Color(0xFF1C1529);

  /// Cartes posées sur une scène 3D uniquement (avec BackdropFilter blur 24).
  static const Color darkGlass = Color(0xB815101F);

  // Rôles de texte et traits du thème sombre
  static const Color darkTextPrimary = Color(0xFFF2F2F6);
  static const Color darkTextSecondary = Color(0xFF9A9AAE);
  static const Color darkTextTertiary = Color(0xFF7A7A8C);
  static const Color darkIconInactive = Color(0xFF6A6A7E);
  static const Color darkBorder = Color(0x12FFFFFF);
  static const Color darkBorderStrong = Color(0x24FFFFFF);

  /// Trou central de l'anneau de forme.
  static const Color ringHole = Color(0xFF0E0916);

  // Surfaces — thème clair (secondaire) et OLED
  static const Color lightBackground = Color(0xFFFAFAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF4F4F6);
  static const Color oledBackground = Color(0xFF000000);

  // Teintes dérivées récurrentes (handoff/design-tokens.md)
  static const Color primaryHalo = Color(0x4D9B30FF); // primary .30
  static const Color primaryCardStrong = Color(0x479B30FF); // primary .28
  static const Color primaryCardSoft = Color(0x0D9B30FF); // primary .05
  static const Color primaryFill = Color(0x739B30FF); // primary .45
  static const Color accentBadgeBg = Color(0x1FFF7A45); // accent .12
  static const Color accentBadgeBorder = Color(0x47FF7A45); // accent .28
  static const Color neutralBadgeBg = Color(0x12FFFFFF); // blanc .07
  static const Color neutralBadgeText = Color(0xFFD3D3E4);
  static const Color gaugeTrack = Color(0x12FFFFFF); // blanc .07
  static const Color primaryLightBorder = Color(0x4DC88BFF); // primaryLight .30
  static const Color difficultyTrack = Color(0x1FFFFFFF); // blanc .12
  static const Color vignetteBorder = Color(0x38C88BFF); // primaryLight .22
  static const Color rowDivider = Color(0x0FFFFFFF); // blanc .06
  static const Color heatEmpty = Color(0x0DFFFFFF); // blanc .05
  static const Color heatOutOfMonth = Color(0x08FFFFFF); // blanc .03

  /// Remplissage d'un jour du calendrier selon l'intensité 0..1 (violet).
  static Color heatFill(double intensity) => Color.lerp(
        const Color(0x809B30FF),
        const Color(0xE69B30FF),
        intensity.clamp(0, 1),
      )!;
}
