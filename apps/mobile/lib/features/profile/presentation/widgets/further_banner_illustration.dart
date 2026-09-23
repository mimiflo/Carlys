import 'dart:math' as math;

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
/// Sa GÉOMÉTRIE est publique ([boxWidthFor], [opaqueFromFor]) parce que la
/// bannière en a besoin : c'est elle qui tient son texte hors de la partie
/// pleine de l'image. Une seule source, sans quoi le texte et l'image
/// finiraient par ne plus s'accorder sur l'endroit où l'image devient pleine.
class FurtherBannerIllustration extends StatelessWidget {
  const FurtherBannerIllustration({super.key});

  /// WebP 1280 × 720 pixels, qualité 92 : 19 Ko, contre 1,7 Mo pour le PNG
  /// fourni, pour un écart moyen de 0,76 sur 255 par pixel. La boîte de
  /// l'image ne dépasse jamais 230 points de large ([boxWidthFor]) : à la
  /// hauteur de référence, 1280 pixels la couvrent jusqu'en densité 4 sans
  /// agrandissement.
  static const String asset = 'assets/illustrations/sommet.webp';

  /// Rapport largeur / hauteur du fichier (1280 × 720) — un test le vérifie
  /// sur le fichier décodé.
  static const double imageAspect = 1280 / 720;

  /// Hauteur de la bannière sur la maquette, et hauteur MINIMALE de la
  /// bannière réelle. La largeur de l'image se règle sur elle, et non sur
  /// la hauteur réelle : un texte agrandi, qui fait grandir la bannière,
  /// ferait sinon grandir l'image vers la gauche, jusque sous le texte.
  static const double referenceHeight = 96;

  /// Le fondu du haut et du bas, en fractions de la hauteur de l'IMAGE —
  /// quand la bannière est plus haute qu'elle (voir [build]).
  static const List<double> verticalFadeStops = [0, 0.15, 0.85, 1];

  /// Part de la carte occupée par l'image, sur la droite — sur un
  /// téléphone. Au-delà, c'est [maxAspect] qui borne.
  static const double widthFactor = 0.62;

  /// Rapport largeur / hauteur maximal de la boîte : celui du téléphone de
  /// référence (224 × 96 sur 393 points), arrondi. Sans cette borne, une
  /// carte large (tablette, paysage) élargissait la boîte, `BoxFit.cover`
  /// agrandissait l'image en proportion et en rognait le haut — le fanion,
  /// qui est le sujet même de l'illustration, sortait du cadre.
  static const double maxAspect = 2.4;

  /// Le fondu, en fractions de la largeur de la BOÎTE : transparente au bord
  /// gauche, pleine à 30 %. La lune commence à 29,4 % de l'image, mesuré
  /// sur le PNG fourni comme sur le WebP : le fondu s'achève sur son bord
  /// sans entamer le disque. Ne pas reculer ce point — à un tiers, l'alpha
  /// ne serait que de 0,88 au bord de la lune.
  static const List<double> fadeStops = [0, 0.3];

  static const _logger = AppLogger('FurtherBannerIllustration');

  /// Largeur de la boîte de l'image dans une carte de [cardWidth] points.
  static double boxWidthFor(double cardWidth) =>
      math.min(cardWidth * widthFactor, referenceHeight * maxAspect);

  /// Abscisse, depuis le bord gauche de la carte, où l'image devient
  /// PLEINE. À gauche, on lit la carte ou l'image en fondu ; à droite,
  /// l'image seule — lune comprise.
  static double opaqueFromFor(double cardWidth) =>
      cardWidth - boxWidthFor(cardWidth) * (1 - fadeStops.last);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = boxWidthFor(constraints.maxWidth);
        final imageHeight = width / imageAspect;

        Widget image = Image.asset(
          asset,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          // Une image manquante ou illisible laisse la carte nue — le texte
          // et le chevron suffisent à la porte — mais se DIT dans les
          // journaux : un décor disparu ne se remarque pas à l'œil.
          errorBuilder: (context, error, stackTrace) {
            _logger.warning('Illustration introuvable : $asset', error: error);
            return const SizedBox.shrink();
          },
        );

        // Un texte agrandi fait grandir la bannière au-delà de l'image.
        // L'image garde alors SON cadrage — pleine largeur, centrée — et se
        // fond dans la carte en haut et en bas. L'agrandir pour couvrir la
        // hauteur la faisait déborder sur les côtés : la lune glissait sous
        // le texte, ou sous le chevron, selon l'ancrage. Ainsi, la lune et
        // le fanion restent exactement là où ils sont à la taille normale.
        if (imageHeight < constraints.maxHeight) {
          image = Center(
            child: SizedBox(
              width: width,
              height: imageHeight,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.neutral0Clear,
                    AppColors.neutral0,
                    AppColors.neutral0,
                    AppColors.neutral0Clear,
                  ],
                  stops: verticalFadeStops,
                ).createShader(rect),
                child: image,
              ),
            ),
          );
        }

        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                colors: [AppColors.neutral0Clear, AppColors.neutral0],
                stops: fadeStops,
              ).createShader(rect),
              child: image,
            ),
          ),
        );
      },
    );
  }
}
