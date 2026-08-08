import 'dart:math' as math;
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
              //
              // ÉCART ASSUMÉ sur la HAUTEUR. La spécification lui donne toute
              // la hauteur ; la planche validée était LARGE, et `cover` n'y
              // rognait qu'un quart du cliché — on y voyait la silhouette
              // entière et le logo dans son dos. Sur un écran de téléphone, la
              // même boîte est étroite et haute : `cover` s'y règle sur la
              // hauteur, agrandit d'autant, et n'en garde plus que 43 % de
              // largeur — un gros plan qui perd et la silhouette et le logo.
              // Lui donner moins de hauteur réduit l'agrandissement, donc rend
              // le cadrage de la planche. Le bas manquant est du fond, que le
              // voile de pied de page couvre déjà.
              Positioned(
                top: 0,
                right: 0,
                width: 0.62 * w,
                height: AthletePhotoFraming.heightFactor * h,
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

/// Cadrage de la photographie : les seuls chiffres qui commandent la taille et
/// la position de la personne à l'écran.
///
/// Sortis du widget pour être vérifiables sur toutes les tailles d'écran —
/// c'est l'endroit du design qui se dérègle le plus vite, et le seul dont la
/// spécification donne une exigence plutôt qu'une valeur.
abstract final class AthletePhotoFraming {
  /// Dimensions du fichier, et position du LOGO DORSAL dedans (mesurées).
  static const Size source = Size(1024, 1536);
  static const double markLeft = 565;
  static const double markRight = 636;

  /// Part de la hauteur d'écran occupée par le cliché.
  ///
  /// **ÉCART ASSUMÉ** : la spécification lui donne toute la hauteur. Elle a été
  /// validée sur une planche LARGE, où `cover` ne rognait qu'un quart du
  /// cliché — on y voyait la silhouette entière et le logo dans le dos. Sur un
  /// écran de téléphone, la même boîte est étroite et haute : `cover` s'y règle
  /// sur la hauteur, agrandit d'autant, et n'en garde que 43 % de largeur — un
  /// gros plan qui perd et la silhouette et le logo. Moins de hauteur = moins
  /// d'agrandissement = plus de largeur montrée. Au-delà de ~0.75, les bras
  /// ressortent du cadre.
  static const double heightFactor = 0.72;

  /// Où le logo dorsal tombe dans le cadre.
  ///
  /// La spécification donne `object-position: 22% top`, relevé sur la même
  /// planche large ; sur un téléphone, ce chiffre laisse le logo juste hors
  /// champ. Elle tranche pourtant : « le logo dans le dos de l'athlète doit
  /// rester visible ». On garde donc l'exigence plutôt que le chiffre.
  ///
  /// Aux deux tiers du cadre, les DEUX bras entrent. Plus à droite — la planche
  /// large met le logo à 90 % de la page — le cadrage se resserre sur le buste
  /// et coupe le bras droit.
  static const double markPlacement = 0.63;

  /// Fondu du BAS, en fraction de la hauteur du cadre.
  ///
  /// Absent de la référence, et pour cause : la photographie y occupe toute la
  /// hauteur, elle n'a pas de bord bas. Lui en donner un sans l'éteindre
  /// trancherait la personne au couteau, en travers des cuisses ; le voile de
  /// pied de page ne suffit pas, il ne commence qu'à 62 %.
  static const List<double> bottomFade = [0.74, 1.0];

  /// Cadrage horizontal qui pose le logo dorsal à [markPlacement] du cadre.
  ///
  /// `cover` agrandit le cliché jusqu'à couvrir la boîte, puis en rogne le
  /// surplus ; `Alignment.x` choisit quelle part de ce surplus part à gauche.
  /// On ne fait qu'inverser la relation.
  static double alignmentFor(Size box) {
    final scale =
        math.max(box.width / source.width, box.height / source.height);
    final window = box.width / scale; // en pixels du fichier
    final slack = source.width - window; // ce que `cover` va rogner
    if (slack <= 0) return 0;
    final left = (markLeft + markRight) / 2 - markPlacement * window;
    return (2 * left / slack - 1).clamp(-1.0, 1.0);
  }

  /// Fenêtre du cliché réellement visible, en pixels du fichier.
  static (double, double) windowFor(Size box) {
    final scale =
        math.max(box.width / source.width, box.height / source.height);
    final window = box.width / scale;
    final left = (1 + alignmentFor(box)) / 2 * (source.width - window);
    return (left, left + window);
  }
}

/// La photographie : lueur de marque, légère baisse de luminosité, fondus des
/// bords gauche et bas.
///
/// Les fondus ne sont pas des ornements : sans eux, la découpe rectangulaire du
/// cliché se voit — un trait vertical au milieu de la page, un trait horizontal
/// en travers des cuisses.
class _AthletePhoto extends StatelessWidget {
  const _AthletePhoto();

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
    return LayoutBuilder(
      builder: (context, c) => RepaintBoundary(
        child: _framed(Size(c.maxWidth, c.maxHeight)),
      ),
    );
  }

  Widget _framed(Size box) {
    final image = Image(
      image: const AssetImage(WelcomeBackdrop.athleteAsset),
      fit: BoxFit.cover,
      alignment: Alignment(AthletePhotoFraming.alignmentFor(box), -1),
      excludeFromSemantics: true,
    );

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        stops: AthletePhotoFraming.bottomFade,
      ).createShader(rect),
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
    );
  }
}
