import 'package:flutter/material.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../design_system/design_system.dart';

/// L'illustration de « Toujours plus loin » : le sommet au fanion, sous une
/// lune violette — fournie par le produit le 23 septembre 2026.
///
/// Posée sur la droite de la bannière et FONDUE dans la carte par la gauche,
/// comme sur la maquette : sans le fondu, le bord de l'image se lirait comme
/// un trait vertical au milieu de la carte. Le fondu agit sur l'ALPHA de
/// l'image (`BlendMode.dstIn`), pas par un voile de couleur posé dessus :
/// c'est donc le fond de la carte lui-même qui apparaît, quel qu'il soit, et
/// aucune teinte nouvelle n'entre dans l'écran. Même technique que la
/// photographie de la page de bienvenue.
///
/// Elle a remplacé un paysage peint à la main (`CustomPainter`), bouche-trou
/// en attendant l'image.
class FurtherBannerIllustration extends StatelessWidget {
  const FurtherBannerIllustration({super.key});

  /// WebP 1280 × 720, qualité 92 : 19 Ko, contre 1,7 Mo pour le PNG fourni,
  /// pour un écart moyen de 0,76 sur 255 par pixel. 1280 points couvrent la
  /// bannière d'une tablette en densité 2 ; au-delà, rien ne se verrait.
  static const String asset = 'assets/illustrations/sommet.webp';

  /// Part de la bannière occupée par l'image, sur la droite. Le reste est au
  /// texte, sur le fond nu de la carte : son contraste ne dépend pas du décor.
  static const double widthFactor = 0.62;

  /// Le fondu, en fractions de la largeur de l'IMAGE : transparente au bord
  /// gauche, pleine au tiers. Assez tôt pour que la lune, qui commence au
  /// tiers de l'image, se lise entière.
  static const List<double> fadeStops = [0, 0.3];

  static const _logger = AppLogger('FurtherBannerIllustration');

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        heightFactor: 1,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            colors: [AppColors.neutral0Clear, AppColors.neutral0],
            stops: fadeStops,
          ).createShader(rect),
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            // Une image manquante ou illisible laisse la carte nue — le
            // texte et le chevron suffisent à la porte — mais se DIT dans
            // les journaux : un décor disparu ne se remarque pas à l'œil.
            errorBuilder: (context, error, stackTrace) {
              _logger.warning(
                'Illustration introuvable : $asset',
                error: error,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
