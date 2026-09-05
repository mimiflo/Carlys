import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/progression.dart';

/// LES CINQ CRANS DE MAJESTÉ.
///
/// Chaque cran ajoute **un élément de FABRICATION**, jamais seulement une
/// couleur : surface nue → filet → cadre gravé → coins et guillochage →
/// plaque bordée de dégradé. C'est ce qui fait qu'un palier se ressent au
/// lieu de se lire, et c'est le reproche exact fait à la version précédente,
/// où la majesté n'était qu'une bordure violette et une ombre.
///
/// ## Un arbitrage du handoff
///
/// Le document donne deux jeux de tailles pour la carte de titre : celles de
/// l'ÉCRAN (§3 : nom en 30, total en 46 pour « Maître ») et celles de la
/// PLANCHE DE REVUE (§7 : nom en 22, total en 26), qui montre les cinq crans
/// côte à côte et les réduit donc tous. Ce sont les tailles de l'écran qui
/// sont retenues ici, la planche n'étant pas un écran de l'application.
///
/// La typographie participe elle aussi à la montée : le Display est un cran
/// de majesté, un compte neuf ne l'a pas.
class Majesty {
  const Majesty({
    required this.tier,
    required this.surface,
    required this.border,
    required this.borderWidth,
    required this.gradientEdge,
    required this.guilloche,
    required this.corners,
    required this.halo,
    required this.nameStyle,
    required this.totalStyle,
    required this.gaugeHeight,
    required this.gaugeFill,
    required this.sealEarned,
  });

  final CarlysTitle tier;

  /// Fond de la carte. Un dégradé radial à partir du quatrième cran : la
  /// lumière vient d'un coin, comme sur une plaque tenue en main.
  final Gradient surface;

  final Color? border;
  final double borderWidth;

  /// Bordure d'un pixel en DÉGRADÉ (dernier cran) : un conteneur extérieur
  /// dégradé, un intérieur plein, un pixel d'écart.
  final bool gradientEdge;

  /// Grain diagonal. `null` tant qu'il n'est pas gagné.
  final double? guilloche;

  /// Équerres aux coins : 0, 2 (haut-gauche et bas-droite) ou 4.
  final int corners;

  final bool halo;

  final TextStyle nameStyle;
  final TextStyle totalStyle;

  final double gaugeHeight;

  /// `null` pour une piste en tirets : le compteur n'est pas ouvert.
  final Gradient? gaugeFill;

  /// Le sceau du cran est-il frappé, ou seulement dessiné ?
  final bool sealEarned;

  /// La surface NUE des deux premiers crans. Publique : c'est elle qui sert
  /// de repère pour vérifier que le troisième cran change bien de matière.
  static const Gradient plainSurface = LinearGradient(
    colors: [AppColors.darkSurface, AppColors.darkSurface],
  );

  static const Gradient _engraved = LinearGradient(
    colors: [AppColors.darkSurfaceAlt, AppColors.darkSurfaceAlt],
  );

  static const Gradient _master = RadialGradient(
    center: Alignment(0.7, -1),
    radius: 1.4,
    colors: [AppColors.surfaceEngraved, AppColors.darkSurfaceAlt],
  );

  static const Gradient _icon = RadialGradient(
    center: Alignment(0.7, -1),
    radius: 1.5,
    colors: [
      AppColors.surfaceIcon,
      AppColors.darkSurfaceAlt,
      AppColors.darkSurface,
    ],
    stops: [0, 0.55, 1],
  );

  static const Gradient _flat = LinearGradient(
    colors: [AppColors.primaryDark, AppColors.primaryDark],
  );

  static const Gradient _rising = LinearGradient(
    colors: [AppColors.primaryDark, AppColors.primary],
  );

  static Majesty of(CarlysTitle tier) => switch (tier) {
    // I — la surface nue. C'est un point de départ, il doit en avoir
    // l'air : rien à retirer, tout à gagner.
    CarlysTitle.apprenti => Majesty(
      tier: tier,
      surface: plainSurface,
      border: null,
      borderWidth: 0,
      gradientEdge: false,
      guilloche: null,
      corners: 0,
      halo: false,
      nameStyle: AppTypography.title.copyWith(color: AppColors.darkTextPrimary),
      totalStyle: AppTypography.metricS.copyWith(
        color: AppColors.darkTextSecondary,
      ),
      gaugeHeight: 6,
      gaugeFill: null,
      sealEarned: false,
    ),
    // II — le filet.
    CarlysTitle.architecte => Majesty(
      tier: tier,
      surface: plainSurface,
      border: AppColors.darkBorder,
      borderWidth: 1,
      gradientEdge: false,
      guilloche: null,
      corners: 0,
      halo: false,
      nameStyle: AppTypography.title.copyWith(color: AppColors.darkTextPrimary),
      totalStyle: AppTypography.metricM.copyWith(
        color: AppColors.darkTextPrimary,
      ),
      gaugeHeight: 6,
      gaugeFill: _flat,
      sealEarned: true,
    ),
    // III — le cadre gravé : la surface change, le nom prend le Display.
    CarlysTitle.artisan => Majesty(
      tier: tier,
      surface: _engraved,
      border: AppColors.darkBorderStrong,
      borderWidth: 1,
      gradientEdge: false,
      guilloche: null,
      corners: 0,
      halo: false,
      nameStyle: AppTypography.display.copyWith(
        color: AppColors.darkTextPrimary,
      ),
      totalStyle: AppTypography.metricL.copyWith(
        color: AppColors.darkTextPrimary,
      ),
      gaugeHeight: 6,
      gaugeFill: _rising,
      sealEarned: true,
    ),
    // IV — les coins et le guillochage.
    CarlysTitle.maitre => Majesty(
      tier: tier,
      surface: _master,
      border: AppColors.majestyBorder,
      borderWidth: 1,
      gradientEdge: false,
      guilloche: 9,
      corners: 2,
      halo: false,
      nameStyle: AppTypography.display.copyWith(
        color: AppColors.darkTextPrimary,
      ),
      totalStyle: AppTypography.metricXL.copyWith(
        color: AppColors.darkTextPrimary,
      ),
      gaugeHeight: 8,
      gaugeFill: AppColors.gauge,
      sealEarned: true,
    ),
    // V — la plaque bordée de dégradé, quatre équerres, un halo.
    CarlysTitle.icone => Majesty(
      tier: tier,
      surface: _icon,
      border: null,
      borderWidth: 0,
      gradientEdge: true,
      guilloche: 7,
      corners: 4,
      halo: true,
      nameStyle: AppTypography.display.copyWith(
        color: AppColors.darkTextPrimary,
      ),
      totalStyle: AppTypography.metricXL.copyWith(
        color: AppColors.darkTextPrimary,
      ),
      gaugeHeight: 8,
      gaugeFill: AppColors.gauge,
      sealEarned: true,
    ),
  };

  /// Le rang du cran, en chiffres romains. Il vient du domaine : c'est le
  /// même chiffre que celui frappé sur le sceau du titre, et deux tables
  /// finiraient par diverger.
  String get roman => tier.roman;

  /// « 4 / 5 PALIERS » — où l'on en est dans le chemin, pas un score.
  String get rank => '${tier.index + 1} / ${CarlysTitle.values.length}';
}
