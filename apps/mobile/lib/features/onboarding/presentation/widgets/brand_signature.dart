import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Signature de marque : le sceau, le mot CARLYS, la devise.
///
/// Le sceau est l'image fournie par la direction artistique, détourée sur
/// fond transparent — pas un dessin approximatif : c'est la marque, elle ne
/// se redessine pas.
///
/// **Le sceau est la seule couleur de cette page.** Le mot et la devise sont
/// en blanc : peindre du texte au dégradé juste sous un logo qui EST un
/// dégradé ne l'accompagne pas, ça le concurrence.
class BrandSignature extends StatelessWidget {
  const BrandSignature({super.key});

  static const String markAsset = 'assets/brand/carlys-mark.png';

  /// Géométrie : sceau de 120, mot en 40 très espacé, devise en 13 espacée.
  ///
  /// Le fichier du sceau porte sa propre lueur et une marge autour d'elle :
  /// la hauteur donnée ici couvre le tout, le tracé lui-même occupe moins.
  static const double _markSize = 120;
  static const double _wordSize = 40;
  static const double _wordTracking = 10;
  static const double _mottoSize = 13;
  static const double _mottoTracking = 5;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carlys, l’art de devenir',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              markAsset,
              height: _markSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
