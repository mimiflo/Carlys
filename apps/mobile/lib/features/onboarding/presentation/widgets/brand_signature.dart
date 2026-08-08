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
  const BrandSignature({super.key});

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
    Shadow(color: Color(0xD906060C), offset: Offset(0, 2), blurRadius: 18),
    Shadow(color: Color(0x9906060C), offset: Offset(0, 1), blurRadius: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carlys, l’art de devenir',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandGlowImage(
              glows: [(Color(0x59CD2EDA), _markGlowBlur / 2)],
              image: Image(
                image: AssetImage(markAsset),
                height: _markSize,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'CARLYS',
              style: AppTypography.display.copyWith(
                fontSize: _wordSize,
                height: 1,
                letterSpacing: _wordTracking,
                fontWeight: FontWeight.w300,
                color: AppColors.neutral0,
                shadows: blockShadows,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'L’ART DE DEVENIR',
              style: AppTypography.label.copyWith(
                fontSize: _mottoSize,
                letterSpacing: _mottoTracking,
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
