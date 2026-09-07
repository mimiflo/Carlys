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
}
