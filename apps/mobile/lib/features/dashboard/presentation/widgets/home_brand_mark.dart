import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../onboarding/presentation/widgets/brand_signature.dart';

/// Le sceau de marque de l'en-tête, halo violet compris.
///
/// Il reprend l'image de la page de bienvenue — la même signature du premier
/// jour au centième, sans deuxième fichier à tenir à jour.
///
/// Le halo suit la SILHOUETTE, pas la boîte. Une ombre portée classique
/// (`BoxShadow`) dessine le rectangle du conteneur : sous un sceau détouré,
/// elle posait un bloc violet qui donnait l'image pour opaque. Ici la marque
/// est recopiée en aplat violet, floutée, puis l'originale se pose dessus —
/// l'équivalent exact du `drop-shadow` de la maquette.
class HomeBrandMark extends StatelessWidget {
  const HomeBrandMark({super.key});

  /// Hauteur du sceau : une image, qui ne suit pas l'échelle du texte.
  static const double height = 15;

  /// Le flou d'un `drop-shadow` CSS de rayon r vaut un sigma de r / 2.
  static const double _glowSigma = 5;

  @override
  Widget build(BuildContext context) {
    const mark = Image(
      image: AssetImage(BrandSignature.markAsset),
      height: height,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      // La marque est décorative ici : elle ne doit pas retarder la première
      // image de l'écran le plus ouvert de l'application.
      gaplessPlayback: true,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: _glowSigma, sigmaY: _glowSigma),
          child: ColorFiltered(
            // `srcIn` garde l'alpha du sceau et n'en remplace que la
            // couleur : c'est ce qui fait une silhouette, et non un carré.
            colorFilter: ColorFilter.mode(
              AppColors.primary.withValues(alpha: 0.45),
              BlendMode.srcIn,
            ),
            child: mark,
          ),
        ),
        mark,
      ],
    );
  }
}
