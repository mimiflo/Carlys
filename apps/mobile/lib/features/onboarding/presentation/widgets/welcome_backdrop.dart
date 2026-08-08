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

              // 3 — la photographie, ancrée à droite sur toute la hauteur.
              // Sa largeur se déduit du cadrage voulu : voir
              // [AthletePhotoFraming].
              Positioned(
                top: AthletePhotoFraming.dropFactor * h,
                right: 0,
                width: AthletePhotoFraming.boxFor(Size(w, h)).width,
                height: AthletePhotoFraming.boxFor(Size(w, h)).height,
                child: _AthletePhoto(screen: Size(w, h)),
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

  // ── Trois valeurs relevées sur la planche validée ──────────────────
  //
  // Elles sont exprimées en fractions d'ÉCRAN, pas de cadre : c'est ce qu'on
  // voit, et c'est la seule forme qui se transpose d'un format à l'autre. La
  // spécification, elle, donne des valeurs de cadre (`width: 62%`,
  // `object-position: 22%`) relevées sur une planche au rapport 0,59 ; un
  // téléphone fait 0,46, et les mêmes chiffres y donnent un tout autre cadrage.

  /// Part du cliché montrée en largeur.
  static const double shownWidth = 0.55;

  /// Position du logo dorsal, en fraction de la largeur d'écran.
  ///
  /// La planche le pose à 0,928 ; on le décale un peu à droite, la personne
  /// suivant. Le décalage est borné par lui : au-delà, il sort du cadre, et la
  /// spécification exige qu'il reste visible.
  static const double markScreenX = 0.945;

  /// Descente de la photographie, en fraction de la hauteur d'écran.
  ///
  /// La planche n'en a pas besoin : son format laisse peu de vide, la personne
  /// et le bloc de texte y commencent ensemble. Sur un téléphone, plus haut, le
  /// texte descend d'un quart du vide disponible — et la personne doit suivre,
  /// sans quoi elle reste accrochée au bord haut pendant que les mots
  /// descendent. Ce qui sort en bas est de toute façon couvert par les
  /// vignettes.
  /// Aucune : la tête doit toucher le coin supérieur droit, comme sur la
  /// planche. La descendre l'éloignait du bord et la rapetissait à l'œil.
  static const double dropFactor = 0;

  /// Bornes du fondu du bord gauche, en fractions de la largeur d'écran :
  /// transparent avant la première, opaque après la seconde.
  ///
  /// Ce sont celles de la planche. Les avoir décalées vers la droite, pour
  /// que la personne ne passe pas derrière le texte, la faisait disparaître
  /// aux DEUX TIERS : elle n'était plus un grand élément de fond mais une
  /// vignette confinée à droite. C'est la PLAQUE SOMBRE (couche 7) et le voile
  /// horizontal (couche 4) qui rendent le texte lisible, pas l'effacement de
  /// la photographie.
  static const double fadeFrom = 0.38;
  static const double fadeTo = 0.566;

  /// Part de la hauteur d'écran occupée par le cadre.
  ///
  /// C'est le seul réglage de TAILLE : `cover` se règle sur la hauteur du
  /// cadre, tout le reste en découle. Moins que 1 rapetitit la personne sans
  /// rien changer à la part du cliché montrée. Le bas manquant tombe sous le
  /// bouton, là où le voile de pied de page est déjà opaque.
  static const double heightFactor = 0.92;

  /// Cadre de la photographie, ancré à droite.
  ///
  /// La largeur n'est pas la constante de la spécification mais se DÉDUIT de
  /// [shownWidth] : `cover` se règle sur la hauteur (le cliché est plus large,
  /// proportion gardée, que le cadre), donc c'est la largeur du cadre qui
  /// décide de la part du cliché visible. Fixée à 62 %, elle n'en montrait que
  /// 43 % sur un téléphone contre 55 % sur la planche — d'où le gros plan, la
  /// silhouette perdue et le logo dorsal hors champ.
  static Size boxFor(Size screen) {
    final height = heightFactor * screen.height;
    final width = math.min(
      screen.width,
      shownWidth * source.width * height / source.height,
    );
    return Size(width, height);
  }

  /// Cadrage horizontal qui pose le logo dorsal à [markScreenX] de l'écran.
  ///
  /// `cover` agrandit le cliché jusqu'à couvrir le cadre, puis en rogne le
  /// surplus ; `Alignment.x` choisit quelle part de ce surplus part à gauche.
  /// On ne fait qu'inverser la relation.
  static double alignmentFor(Size screen) {
    final box = boxFor(screen);
    final window = _windowWidth(box);
    final slack = source.width - window;
    if (slack <= 0) return 0;
    final boxLeft = 1 - box.width / screen.width;
    final placement = (markScreenX - boxLeft) / (box.width / screen.width);
    final left = (markLeft + markRight) / 2 - placement * window;
    return (2 * left / slack - 1).clamp(-1.0, 1.0);
  }

  /// Bornes du fondu, ramenées du repère de l'écran à celui du cadre.
  static List<double> fadeStopsFor(Size screen) {
    final box = boxFor(screen);
    final boxLeft = 1 - box.width / screen.width;
    final span = box.width / screen.width;
    return [
      ((fadeFrom - boxLeft) / span).clamp(0.0, 1.0),
      ((fadeTo - boxLeft) / span).clamp(0.0, 1.0),
    ];
  }

  /// Fenêtre du cliché réellement visible, en pixels du fichier.
  static (double, double) windowFor(Size screen) {
    final box = boxFor(screen);
    final window = _windowWidth(box);
    final left = (1 + alignmentFor(screen)) / 2 * (source.width - window);
    return (left, left + window);
  }

  static double _windowWidth(Size box) {
    final scale =
        math.max(box.width / source.width, box.height / source.height);
    return box.width / scale;
  }
}

/// La photographie : lueur de marque, légère baisse de luminosité, fondus des
/// bords gauche et bas.
///
/// Les fondus ne sont pas des ornements : sans eux, la découpe rectangulaire du
/// cliché se voit — un trait vertical au milieu de la page, un trait horizontal
/// en travers des cuisses.
class _AthletePhoto extends StatelessWidget {
  const _AthletePhoto({required this.screen});

  /// Taille de l'ÉCRAN, pas du cadre : le cadrage et le fondu sont exprimés
  /// en fractions d'écran, seul repère qui se transpose d'un format à l'autre.
  final Size screen;

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
    final stops = AthletePhotoFraming.fadeStopsFor(screen);
    final image = Image(
      image: const AssetImage(WelcomeBackdrop.athleteAsset),
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
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
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
    );
  }
}
