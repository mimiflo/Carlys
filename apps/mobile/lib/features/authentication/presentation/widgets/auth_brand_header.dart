import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../onboarding/presentation/widgets/brand_signature.dart';

/// Signature de marque COMPACTE des écrans d'entrée : le sceau réduit à
/// gauche, le mot et la devise à droite — la disposition de la maquette.
///
/// C'est une seconde COMPOSITION du même verrouillage, pas une seconde
/// marque : le sceau est le même fichier que [BrandSignature.markAsset], le
/// mot et la devise gardent leur typographie et leurs espacements relatifs.
/// La version verticale reste celle des pages de marque pleines
/// ([BrandSignature]) ; celle-ci sert d'en-tête quand l'écran a un contenu à
/// montrer dessous.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  /// Géométrie de la maquette : sceau de 44, mot en 22 espacé, devise en 9.
  static const double _markSize = 44;
  static const double _wordSize = 22;
  static const double _wordTracking = 5;
  static const double _mottoSize = 9;
  static const double _mottoTracking = 3;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carlys, l’art de devenir',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Image(
              image: AssetImage(BrandSignature.markAsset),
              height: _markSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CARLYS',
                  style: AppTypography.display.copyWith(
                    fontSize: _wordSize,
                    height: 1,
                    letterSpacing: _wordTracking,
                    fontWeight: FontWeight.w300,
                    color: AppColors.neutral0,
                    shadows: AppShadows.brandText,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'L’ART DE DEVENIR',
                  style: AppTypography.label.copyWith(
                    fontSize: _mottoSize,
                    letterSpacing: _mottoTracking,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkTextSecondary,
                    shadows: AppShadows.brandText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
