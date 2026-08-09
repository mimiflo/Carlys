import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import 'scene3d.dart';

/// État d'une particule à un instant donné.
///
/// La position est exprimée en **demi-cadres à sa propre profondeur**
/// (−1 = bord gauche ou bas, +1 = bord droit ou haut), jamais en pixels : le
/// modèle reste ainsi vérifiable sans caméra ni canevas, et une particule
/// lointaine balaie la même part de l'écran qu'une particule proche.
typedef SpeckState = ({
  double across,
  double fall,
  double size,
  double opacity,
});

/// Petites particules blanches qui dérivent **autour du cœur**, et devant lui.
///
/// Même famille que le flux sanguin déjà en orbite dans la scène — un point
/// clair, rien d'autre — mais elles, on les remarque : elles passent de temps
/// en temps, plus grosses, et traversent le cadre au lieu de tourner.
///
/// C'est un accent, pas une nuée : chaque particule ne vit qu'un tiers du
/// cycle, si bien qu'à un instant donné quatre ou cinq flottent au plus.
/// Aucun aléatoire — le rendu doit être reproductible d'une image à l'autre et
/// d'un test à l'autre.
abstract final class HeartSpecks {
  /// Vivier de particules. La moitié passe devant le cœur, l'autre derrière.
  static const int count = 14;

  /// Durée du cycle, en secondes.
  ///
  /// Tout état est fonction de l'avancement DANS ce cycle : une particule
  /// retrouve donc exactement sa place au tour suivant, et aucune ne se
  /// téléporte — propriété vérifiée par les tests, sans laquelle la dérive
  /// lente rendrait le saut criant.
  static const double cycle = 30;

  /// Bornes de vie, en secondes. Les particules lointaines tombent plus
  /// longtemps : la parallaxe ne vient pas que de la taille.
  static const double shortestLife = 9;
  static const double longestLife = 14;

  /// Bande de profondeur **interdite** : celle qu'occupe la masse du cœur
  /// (±1,4 unité une fois le maillage mis à l'échelle 1,62).
  ///
  /// Aucune particule n'y entre. Chacune est donc franchement derrière ou
  /// franchement devant — il n'y a rien à départager, ce qu'un rendu sans
  /// tampon de profondeur ne saurait de toute façon pas faire.
  static const double behindZ = -1.7;
  static const double behindSpread = 1.3;
  static const double frontZ = 1.9;
  static const double frontSpread = 1.0;

  /// Course verticale, en demi-cadres. Volontairement plus courte que le
  /// cadre : au-delà, la particule passerait le plus clair de sa vie sous le
  /// masque du conteneur, donc invisible.
  static const double _travel = 0.85;

  /// Étendue horizontale, en demi-cadres. Les coins sont éteints par le masque
  /// radial de [AppSceneContainer] : les y envoyer serait les perdre.
  static const double _spread = 0.78;

  /// Rayon d'une particule moyenne, en fraction du plus petit côté de la scène.
  ///
  /// Relevé sur le rendu : la plus grosse du premier plan mesure alors 6 points
  /// de diamètre sur une scène de 330, la plus petite du fond en mesure 2 —
  /// soit à peine plus que les points du flux sanguin, ce qu'il faut pour
  /// qu'elles appartiennent à la même famille sans se confondre avec lui.
  static const double _radius = 0.0055;

  /// Étalement du halo, en multiples du rayon.
  static const double _glowSpread = 2.8;

  /// Blanc franc, comme demandé : le violet appartient au cœur, pas à ce qui
  /// flotte autour.
  static const Color _white = AppColors.neutral0;

  /// La particule [index] passe-t-elle **devant** le cœur ?
  static bool isInFront(int index) => index.isEven;

  /// Profondeur de la particule [index], en unités monde.
  static double depthOf(int index) {
    final spread = sceneNoise(index * 1.0 + 17);
    return isInFront(index)
        ? frontZ + spread * frontSpread
        : behindZ - spread * behindSpread;
  }

  /// Durée de vie de la particule [index], en secondes.
  static double lifeOf(int index) =>
      shortestLife +
      sceneNoise(index * 1.0 + 53) * (longestLife - shortestLife);

  /// Enveloppe d'apparition : nulle à la naissance ET à la mort, pleine au
  /// milieu. Une particule ne surgit donc jamais, et ne disparaît jamais net.
  @visibleForTesting
  static double envelope(double progress) {
    const rise = 0.18;
    const decay = 0.28;
    final opening = (progress / rise).clamp(0.0, 1.0);
    final closing = ((1 - progress) / decay).clamp(0.0, 1.0);
    final e = math.min(opening, closing);
    return e * e * (3 - 2 * e);
  }

  /// État de la particule [index] à [seconds], ou `null` si elle est **en
  /// sommeil**.
  ///
  /// C'est là tout le « de temps en temps » : les naissances s'égrènent sur le
  /// cycle au lieu de se grouper, et chacune n'occupe qu'une fraction de
  /// celui-ci.
  static SpeckState? stateAt(int index, double seconds) {
    final life = lifeOf(index);
    // Décalage régulier, plus une gigue bornée à un intervalle : l'égrènement
    // reste régulier sans être mécanique.
    final offset =
        (index / count + sceneNoise(index * 1.0 + 7) * 0.6 / count) % 1;
    final phase = (seconds / cycle + offset) % 1;
    final progress = phase * cycle / life;
    if (progress >= 1) {
      return null;
    }

    final sway = math.sin(
      progress * math.pi * 2 * (1 + index % 2) +
          sceneNoise(index * 1.0 + 71) * 6,
    );

    return (
      across: (sceneNoise(index * 1.0 + 131) * 2 - 1) * _spread + sway * 0.11,
      fall: _travel - 2 * _travel * progress,
      size: 0.65 + sceneNoise(index * 1.0 + 233) * 0.35,
      opacity: envelope(progress),
    );
  }

  /// Dessine les particules du plan demandé.
  ///
  /// Deux passes encadrent le cœur : [front] à `false` avant le maillage —
  /// les particules passent alors derrière la masse —, à `true` après.
  static void paint(
    Canvas canvas,
    Size size,
    SceneCamera camera, {
    required double seconds,
    required bool hero,
    required bool front,
  }) {
    // Échelle de référence : le plan du cœur. Les particules proches
    // grossissent, les lointaines rapetissent, dans ce même rapport.
    final reference = camera.pixelsPerUnit(camera.z, size.height);
    final peak = (hero ? 0.85 : 0.62) * (front ? 1 : 0.7);

    for (var index = 0; index < count; index++) {
      if (isInFront(index) != front) {
        continue;
      }
      final state = stateAt(index, seconds);
      if (state == null || state.opacity <= 0) {
        continue;
      }

      final z = depthOf(index);
      final depth = camera.z - z;
      if (depth <= 0.1) {
        continue;
      }
      final unit = camera.pixelsPerUnit(depth, size.height);
      final point = camera.project(
        camera.x + state.across * size.width * 0.5 / unit,
        camera.y + state.fall * size.height * 0.5 / unit,
        z,
        size.width,
        size.height,
      );

      final radius = math.max(
        0.7,
        _radius * size.shortestSide * state.size * (unit / reference),
      );
      _paintSpeck(
        canvas,
        Offset(point.sx, point.sy),
        radius,
        (peak * state.opacity).clamp(0.0, 1.0),
      );
    }
  }

  /// Une particule : un point blanc et son halo, additifs comme tout ce qui
  /// brille dans cette scène.
  static void _paintSpeck(
    Canvas canvas,
    Offset center,
    double radius,
    double alpha,
  ) {
    // Le halo est un dégradé, pas un second disque : un disque uni laisserait
    // un bord franc, ce qui se voit immédiatement sur un fond sombre.
    final glow = radius * _glowSpread;
    canvas.drawCircle(
      center,
      glow,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            _white.withValues(alpha: alpha * 0.34),
            _white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glow)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = _white.withValues(alpha: alpha),
    );
  }
}
