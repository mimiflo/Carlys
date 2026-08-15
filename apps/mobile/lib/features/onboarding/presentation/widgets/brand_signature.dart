import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'brand_glow_image.dart';

/// Signature de marque : le sceau, le mot CARLYS, la devise.
///
/// Le sceau est l'image fournie par la direction artistique, détourée sur fond
/// transparent — pas un dessin approximatif : c'est la marque, elle ne se
/// redessine pas. Il porte sa propre lueur ; le mot et la devise, eux, restent
/// sobres.
class BrandSignature extends StatelessWidget {
  const BrandSignature({
    this.scale = 1,
    this.centered = false,
    super.key,
  });

  /// Échelle du bloc, voir [WelcomeScreen.scaleFor].
  final double scale;

  /// Bloc centré plutôt qu'aligné à gauche.
  ///
  /// La page de marque l'aligne sur sa colonne de texte ; l'écran de
  /// démarrage, lui, n'a que lui à montrer et le pose au milieu. Un
  /// paramètre plutôt qu'une copie : le verrouillage de la marque (sceau,
  /// mot, devise, proportions) ne se redessine pas à deux endroits.
  final bool centered;

  static const String markAsset = 'assets/brand/carlys-mark.png';

  /// Géométrie de la référence : sceau de 120, mot en 40 très espacé, devise
  /// en 13 espacée.
  static const double _markSize = 120;
  static const double _markGlowBlur = 26;
  static const double _wordSize = 40;
  static const double _wordTracking = 10;
  static const double _mottoSize = 13;
  static const double _mottoTracking = 5;

  /// Ombre portée commune à tout le bloc de texte : elle le décolle du cliché
  /// quand la page est vue sur un écran clair ou en plein soleil.
  static const List<Shadow> blockShadows = [
    Shadow(color: Color(0xD908050E), offset: Offset(0, 2), blurRadius: 18),
    Shadow(color: Color(0x9908050E), offset: Offset(0, 1), blurRadius: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carlys, l’art de devenir',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment:
              centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandGlowImage(
              glows: const [(Color(0x59C42EE0), _markGlowBlur / 2)],
              image: Image(
                image: AssetImage(markAsset),
                height: _markSize,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            SizedBox(height: AppSpacing.sm * scale),
            Text(
              'CARLYS',
              style: AppTypography.display.copyWith(
                fontSize: _wordSize * scale,
                height: 1,
                letterSpacing: _wordTracking * scale,
                fontWeight: FontWeight.w300,
                color: AppColors.neutral0,
                shadows: blockShadows,
              ),
            ),
            SizedBox(height: AppSpacing.sm * scale),
            Text(
              'L’ART DE DEVENIR',
              style: AppTypography.label.copyWith(
                fontSize: _mottoSize * scale,
                letterSpacing: _mottoTracking * scale,
                fontWeight: FontWeight.w600,
                color: AppColors.darkTextSecondary,
                shadows: blockShadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
