import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'brand_glow_image.dart';

/// Décor de la page de marque : six couches, du fond vers l'avant.
///
/// Traduction de `handoff/reference/Welcome.dc.html` (design validé). Les
/// proportions sont en fractions de l'écran, comme dans la référence — d'où le
/// [LayoutBuilder] : ces couches n'ont pas de taille propre, elles se déduisent
/// de la page.
///
/// Aucune n'intercepte le toucher.
class WelcomeBackdrop extends StatelessWidget {
  const WelcomeBackdrop({super.key});

  static const String athleteAsset = 'assets/brand/carlys-athlete.png';

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Stack(
            children: [
              // 2 — halo de marque, haut-droite.
              Positioned(
                top: -0.06 * h,
                right: -0.14 * w,
                width: 0.86 * w,
                height: 0.82 * h,
                child: const _Halo(
                  sigma: 14,
                  colors: [
                    Color(0x33CD2EDA),
                    Color(0x1F7B4BF6),
                    Color(0x0006060C),
                  ],
                  stops: [0, 0.46, 0.78],
                ),
              ),

              // 3 — la photographie.
              Positioned(
                top: 0,
                right: 0,
                width: 0.62 * w,
                height: h,
                child: const _AthletePhoto(),
              ),

              // 4 — voile horizontal : la colonne de texte reprend le fond.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppColors.darkBackground,
                        Color(0xC706060C),
                        Color(0x0006060C),
                      ],
                      stops: [0, 0.34, 0.66],
                    ),
                  ),
                ),
              ),

              // 5 — voile bas : les vignettes et le bouton se posent au calme.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x0006060C),
                        Color(0x9906060C),
                        AppColors.darkBackground,
                      ],
                      stops: [0.62, 0.86, 1],
                    ),
                  ),
                ),
              ),

              // 6 — halo indigo derrière le texte.
              Positioned(
                left: -0.18 * w,
                top: 0.02 * h,
                width: 0.78 * w,
                height: 0.62 * h,
                child: const _Halo(
                  sigma: 18,
                  colors: [
                    Color(0x335B5BF6),
                    Color(0x125B5BF6),
                    Color(0x0006060C),
                  ],
                  stops: [0, 0.52, 0.80],
                ),
              ),

              // 7 — plaque sombre sous le texte : c'est elle qui rend les mots
              // lisibles, pas un assombrissement de la personne.
              Positioned(
                left: 0,
                top: 0,
                width: 0.82 * w,
                height: h,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.56, -0.12),
                      radius: 0.5,
                      transform: EllipticGradient(0.78, 0.46),
                      colors: [
                        Color(0xEB000000),
                        Color(0xC7030308),
                        Color(0x6B06060C),
                        Color(0x0006060C),
                      ],
                      stops: [0, 0.42, 0.72, 1],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Rend un [RadialGradient] de Flutter ELLIPTIQUE.
///
/// Flutter dessine un cercle (rayon × plus petit côté) là où la référence CSS
/// dessine une ellipse inscrite dans la boîte. Sans cette correction, un halo
/// posé dans un cadre allongé se contracte en pastille et laisse le reste du
/// cadre vide.
///
/// [rx] et [ry] sont les rayons voulus, en fraction de la largeur et de la
/// hauteur de la boîte (0.5 = l'ellipse touche les bords, soit `closest-side`).
@visibleForTesting
class EllipticGradient extends GradientTransform {
  const EllipticGradient(this.rx, this.ry);

  final double rx;
  final double ry;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final base = bounds.shortestSide / 2;
    if (base <= 0) return Matrix4.identity();
    // L'étirement se fait autour du CENTRE DU DÉGRADÉ, pas de la boîte :
    // sinon un halo décentré se déplacerait en même temps qu'il s'étire.
    final center = bounds.center;
    return Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(rx * bounds.width / base, ry * bounds.height / base, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }
}

/// Halo flouté : dégradé radial elliptique passé à un flou gaussien.
class _Halo extends StatelessWidget {
  const _Halo({
    required this.sigma,
    required this.colors,
    required this.stops,
  });

  final double sigma;
  final List<Color> colors;
  final List<double> stops;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.5,
            transform: const EllipticGradient(0.5, 0.5),
            colors: colors,
            stops: stops,
          ),
        ),
      ),
    );
  }
}

/// La photographie : lueur de marque, légère baisse de luminosité, fondu du
/// bord gauche.
///
/// Le fondu n'est pas un ornement : sans lui, la découpe rectangulaire du
/// cliché se voit comme un trait vertical au milieu de la page.
class _AthletePhoto extends StatelessWidget {
  const _AthletePhoto();

  /// `object-position: 22% top` de la référence.
  static const Alignment _framing = Alignment(-0.56, -1);

  /// Trois lueurs, de la plus serrée à la plus large. Les rayons de la
  /// référence sont des `blur-radius` CSS : l'écart-type gaussien en vaut la
  /// moitié.
  static const List<(Color, double)> _glows = [
    (Color(0x47F7708F), 18 / 2),
    (Color(0x3DCD2EDA), 46 / 2),
    (Color(0x337B4BF6), 96 / 2),
  ];

  @override
  Widget build(BuildContext context) {
    const image = Image(
      image: AssetImage(WelcomeBackdrop.athleteAsset),
      fit: BoxFit.cover,
      alignment: _framing,
      excludeFromSemantics: true,
    );

    return RepaintBoundary(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
          stops: [0, 0.30],
        ).createShader(rect),
        child: BrandGlowImage(
          expand: true,
          glows: _glows,
          image: const ColorFiltered(
            // brightness(0.9) : l'alpha n'est pas touché, sans quoi le
            // détourage se remettrait à baver.
            colorFilter: ColorFilter.matrix(<double>[
              0.9, 0, 0, 0, 0, //
              0, 0.9, 0, 0, 0, //
              0, 0, 0.9, 0, 0, //
              0, 0, 0, 1, 0, //
            ]),
            child: image,
          ),
        ),
      ),
    );
  }
}
