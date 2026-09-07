import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'athlete_photo_framing.dart';
import 'brand_glow_image.dart';

/// La photographie de la page de marque : lueur de marque, légère baisse de
/// luminosité, fondus des bords gauche et bas.
///
/// Les fondus ne sont pas des ornements : sans eux, la découpe rectangulaire du
/// cliché se voit — un trait vertical au milieu de la page, un trait horizontal
/// en travers des cuisses.
class AthletePhoto extends StatelessWidget {
  const AthletePhoto({required this.screen, super.key});

  /// Le fichier détouré, seul cliché de la page de marque.
  static const String asset = 'assets/brand/carlys-athlete.png';

  /// Taille de l'ÉCRAN, pas du cadre : le cadrage et le fondu sont exprimés
  /// en fractions d'écran, seul repère qui se transpose d'un format à l'autre.
  final Size screen;

  /// Trois lueurs, de la plus serrée à la plus large. Les rayons de la
  /// référence sont des `blur-radius` CSS : l'écart-type gaussien en vaut la
  /// moitié.
  static const List<(Color, double)> _glows = [
    (AppColors.backdropBokehAccent, 18 / 2),
    (AppColors.backdropBokehMagenta, 46 / 2),
    (AppColors.backdropBokehIndigo, 96 / 2),
  ];

  @override
  Widget build(BuildContext context) {
    final stops = AthletePhotoFraming.fadeStopsFor(screen);
    final image = Image(
      image: const AssetImage(asset),
      fit: BoxFit.cover,
      alignment: Alignment(AthletePhotoFraming.alignmentFor(screen), -1),
      // Le cliché est AGRANDI à l'affichage : le filtrage par défaut
      // (bilinéaire sur mipmaps) le rendrait mou, la bicubique garde le grain
      // de la peau et le trait des cheveux. Le fichier, lui, n'est PAS
      // retouché — c'est le détourage fourni, dont les bords sont propres.
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    );

    return RepaintBoundary(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.neutral0, AppColors.neutral0Clear],
          stops: AthletePhotoFraming.bottomFade,
        ).createShader(rect),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [AppColors.neutral0Clear, AppColors.neutral0],
            stops: stops,
          ).createShader(rect),
          child: BrandGlowImage(
            expand: true,
            glows: _glows,
            image: ColorFiltered(
              // brightness(0.9) : l'alpha n'est pas touché, sans quoi le
              // détourage se remettrait à baver.
              colorFilter: const ColorFilter.matrix(<double>[
                0.9, 0, 0, 0, 0, //
                0, 0.9, 0, 0, 0, //
                0, 0, 0.9, 0, 0, //
                0, 0, 0, 1, 0, //
              ]),
              child: image,
            ),
          ),
        ),
      ),
    );
  }
}
