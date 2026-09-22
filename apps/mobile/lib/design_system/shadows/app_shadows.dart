import 'package:flutter/widgets.dart';

import '../colors/app_colors.dart';

/// Ombres Carlys (tokens : shadow.*). En thème sombre, préférer les
/// variations de surface aux ombres.
abstract final class AppShadows {
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x1416162A), offset: Offset(0, 1), blurRadius: 3),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1A16162A), offset: Offset(0, 4), blurRadius: 12),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x2416162A), offset: Offset(0, 12), blurRadius: 32),
  ];

  /// Ombre portée du bloc de signature de marque (sceau, mot, devise).
  ///
  /// Une ombre de TEXTE, donc un `Shadow` et non un `BoxShadow` : elle suit
  /// les lettres, pas une boîte.
  static const List<Shadow> brandText = [
    Shadow(
      color: AppColors.brandInkShadow,
      offset: Offset(0, 2),
      blurRadius: 18,
    ),
    Shadow(
      color: AppColors.brandInkShadowTight,
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
  ];

  /// EXTRUSION de l'accroche de marque : cinq ombres PLEINES (sans flou)
  /// décalées d'un pixel chacune, puis une ombre portée. C'est ce qui donne
  /// l'épaisseur ; les remplacer par un flou unique aplatirait le relief.
  ///
  /// **La liste est à l'ENVERS de la référence CSS, volontairement.** CSS
  /// empile les `text-shadow` de haut en bas — la première déclarée est la
  /// plus haute — quand Flutter les peint dans l'ordre, la dernière
  /// par-dessus. Recopiée telle quelle, la pile s'inversait : la teinte la
  /// plus sombre recouvrait les autres et le relief virait au noir au lieu
  /// de s'éclaircir près des lettres.
  ///
  /// Les cinq marches ne DÉRIVENT pas de la palette : c'est un relief gravé,
  /// relevé sur la référence de direction artistique, et non une teinte de
  /// l'application. Elles vivent donc ici, dans le design system, plutôt que
  /// dans le widget qui les portait.
  static const List<Shadow> brandClaimExtrusion = [
    Shadow(color: Color(0xD1000000), offset: Offset(6, 7), blurRadius: 13),
    Shadow(color: Color(0xFF1A1420), offset: Offset(5, 5)),
    Shadow(color: Color(0xFF251C2E), offset: Offset(4, 4)),
    Shadow(color: Color(0xFF31253E), offset: Offset(3, 3)),
    Shadow(color: Color(0xFF3D2F4E), offset: Offset(2, 2)),
    Shadow(color: Color(0xFF4A3A5E), offset: Offset(1, 1)),
  ];

  /// Halo discret pour mettre en avant un élément de marque (records…).
  static List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.35),
      offset: const Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  /// LUEUR du bouton principal : le violet qui déborde sous l'action.
  ///
  /// À ne pas confondre avec [primaryGlow], qui est un halo DISCRET posé
  /// autour d'un élément de marque. Celle-ci est portée : elle tombe de 12
  /// sous le bouton, floute sur 30, et se resserre de 12 pour ne pas
  /// déborder sur les côtés. C'est la signature visuelle d'un appel à
  /// l'action, pas une mise en avant.
  ///
  /// **Quatre écrans la déclaraient chacun pour soi** — la barre d'action
  /// d'une série, la carte de modèle, la barre de l'éditeur de modèle et le
  /// bouton d'accueil de l'embarquement — avec, pour trois d'entre eux, un
  /// triplet privé `_glowBlur` / `_glowSpread` / `_glowOffset` aux MÊMES
  /// valeurs recopiées. Quatre copies d'une même lueur finissent par
  /// diverger : l'une se corrige, les autres restent.
  ///
  /// [alpha] reste un paramètre parce que l'intensité, elle, diffère
  /// réellement d'un écran à l'autre : 0,7 sur un fond de contenu, 0,5 sur
  /// les écrans d'entrée, déjà chargés de lumière.
  static List<BoxShadow> ctaGlow({double alpha = 0.7}) => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: alpha),
      offset: const Offset(0, 12),
      blurRadius: 30,
      spreadRadius: -12,
    ),
  ];
}
