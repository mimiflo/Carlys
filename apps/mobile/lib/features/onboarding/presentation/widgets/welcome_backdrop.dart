import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'athlete_photo.dart';
import 'athlete_photo_framing.dart';

/// Décor de la page de marque : six couches, du fond vers l'avant.
///
/// Traduction de `handoff/reference/Welcome.dc.html` (design validé). Les
/// proportions sont en fractions de l'écran, comme dans la référence — d'où le
/// [LayoutBuilder] : ces couches n'ont pas de taille propre, elles se déduisent
/// de la page.
///
/// La photographie et son cadrage vivent à côté ([AthletePhoto],
/// [AthletePhotoFraming]) : c'est la partie qui se règle, et elle se règle
/// seule.
///
/// Aucune couche n'intercepte le toucher.
class WelcomeBackdrop extends StatelessWidget {
  const WelcomeBackdrop({super.key});

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
                    AppColors.backdropHaloMagenta,
                    AppColors.backdropHaloIndigo,
                    AppColors.backdropClear,
                  ],
                  stops: [0, 0.46, 0.78],
                ),
              ),

              // 3 — la photographie, ancrée à droite sur toute la hauteur.
              // Sa largeur se déduit du cadrage voulu : voir
              // [AthletePhotoFraming].
              Positioned(
                top: AthletePhotoFraming.dropFactor * h,
                right: 0,
                width: AthletePhotoFraming.boxFor(Size(w, h)).width,
                height: AthletePhotoFraming.boxFor(Size(w, h)).height,
                child: AthletePhoto(screen: Size(w, h)),
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
                        AppColors.backdropVeil,
                        AppColors.backdropClear,
                      ],
                      stops: [0, 0.34, 0.66],
                    ),
                  ),
                ),
              ),

              // 5 — voile bas : les vignettes et le bouton se posent au calme.
              //
              // ÉCART ASSUMÉ. La planche l'ouvre à 0,62 et ne le ferme qu'au
              // bord ; le halo de marque, lui, descend jusqu'à 0,76 et laissait
              // le pied de page violacé. Le voile monte donc et se ferme plus
              // tôt : sous 0,88, on est sur le fond, pas sur une nappe colorée.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.backdropClear,
                        AppColors.backdropVeilStrong,
                        AppColors.darkBackground,
                      ],
                      stops: [0.56, 0.76, 0.88],
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
                    AppColors.backdropGlow,
                    AppColors.backdropGlowSoft,
                    AppColors.backdropClear,
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
                        AppColors.backdropPlate,
                        AppColors.backdropPlateEdge,
                        AppColors.backdropVeilSoft,
                        AppColors.backdropClear,
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
  const _Halo({required this.sigma, required this.colors, required this.stops});

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
