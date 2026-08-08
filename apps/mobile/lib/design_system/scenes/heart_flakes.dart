import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import 'scene3d.dart';

/// État d'un cristal à un instant donné.
///
/// La position est exprimée en **demi-cadres à sa propre profondeur**
/// (−1 = bord gauche ou bas, +1 = bord droit ou haut), jamais en pixels : le
/// modèle reste ainsi vérifiable sans caméra ni canevas, et un cristal
/// lointain balaie la même part de l'écran qu'un cristal proche.
typedef FlakeState = ({
  double across,
  double fall,
  double angle,
  double size,
  double opacity,
});

/// Cristaux de givre qui dérivent **autour du cœur**, et devant lui.
///
/// C'est un accent, pas une chute de neige : chaque cristal ne vit qu'un tiers
/// du cycle, si bien qu'à un instant donné quatre ou cinq flottent au plus.
/// Aucun aléatoire — le rendu doit être reproductible d'une image à l'autre et
/// d'un test à l'autre, exactement comme le flux sanguin du cœur.
abstract final class HeartFlakes {
  /// Vivier de cristaux. La moitié passe devant le cœur, l'autre derrière.
  static const int count = 14;

  /// Durée du cycle, en secondes.
  ///
  /// Tout état est fonction de l'avancement DANS ce cycle : un cristal
  /// retrouve donc exactement sa place au tour suivant, et aucun ne se
  /// téléporte — propriété vérifiée par les tests, sans laquelle la dérive
  /// lente rendrait le saut criant.
  static const double cycle = 30;

  /// Bornes de vie, en secondes. Les cristaux lointains tombent plus
  /// longtemps : la parallaxe ne vient pas que de la taille.
  static const double shortestLife = 9;
  static const double longestLife = 14;

  /// Bande de profondeur **interdite** : celle qu'occupe la masse du cœur
  /// (±1,4 unité une fois le maillage mis à l'échelle 1,62).
  ///
  /// Aucun cristal n'y entre. Chacun est donc franchement derrière ou
  /// franchement devant — il n'y a rien à départager, ce qu'un rendu sans
  /// tampon de profondeur ne saurait de toute façon pas faire.
  static const double behindZ = -1.7;
  static const double behindSpread = 1.3;
  static const double frontZ = 1.9;
  static const double frontSpread = 1.0;

  /// Course verticale, en demi-cadres. Volontairement plus courte que le
  /// cadre : au-delà, le cristal passerait le plus clair de sa vie sous le
  /// masque du conteneur, donc invisible.
  static const double _travel = 0.85;

  /// Étendue horizontale, en demi-cadres. Les coins sont éteints par le masque
  /// radial de [AppSceneContainer] : les y envoyer serait les perdre.
  static const double _spread = 0.78;

  /// Rayon d'un cristal moyen, en fraction du plus petit côté de la scène.
  ///
  /// Relevé sur le rendu : le plus gros cristal du premier plan mesure alors
  /// 15 points de pointe à pointe sur une scène de 330, le plus petit du fond
  /// en mesure 5. Au double, le cristal cessait d'être un accent et se posait
  /// sur le cœur comme un motif.
  static const double _radius = 0.014;

  /// Givre : un blanc à peine violacé, tiré des jetons de marque.
  static final Color _ice =
      Color.lerp(AppColors.neutral0, AppColors.primaryLight, 0.35)!;

  /// Le cristal [index] passe-t-il **devant** le cœur ?
  static bool isInFront(int index) => index.isEven;

  /// Profondeur du cristal [index], en unités monde.
  static double depthOf(int index) {
    final spread = sceneNoise(index * 1.0 + 17);
    return isInFront(index)
        ? frontZ + spread * frontSpread
        : behindZ - spread * behindSpread;
  }

  /// Durée de vie du cristal [index], en secondes.
  static double lifeOf(int index) =>
      shortestLife +
      sceneNoise(index * 1.0 + 53) * (longestLife - shortestLife);

  /// Enveloppe d'apparition : nulle à la naissance ET à la mort, pleine au
  /// milieu. Un cristal ne surgit donc jamais, et ne disparaît jamais net.
  @visibleForTesting
  static double envelope(double progress) {
    const rise = 0.18;
    const decay = 0.28;
    final opening = (progress / rise).clamp(0.0, 1.0);
    final closing = ((1 - progress) / decay).clamp(0.0, 1.0);
    final e = math.min(opening, closing);
    return e * e * (3 - 2 * e);
  }

  /// État du cristal [index] à [seconds], ou `null` s'il est **en sommeil**.
  ///
  /// C'est là tout le « de temps en temps » : les naissances s'égrènent sur le
  /// cycle au lieu de se grouper, et chacune n'occupe qu'une fraction de
  /// celui-ci.
  static FlakeState? stateAt(int index, double seconds) {
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
    final turns = 0.6 + sceneNoise(index * 1.0 + 191) * 0.9;
    final direction = index % 3 == 0 ? -1 : 1;

    return (
      across: (sceneNoise(index * 1.0 + 131) * 2 - 1) * _spread + sway * 0.11,
      fall: _travel - 2 * _travel * progress,
      angle: direction * turns * math.pi * 2 * progress,
      size: 0.65 + sceneNoise(index * 1.0 + 233) * 0.35,
      opacity: envelope(progress),
    );
  }

  /// Dessine les cristaux du plan demandé.
  ///
  /// Deux passes encadrent le cœur : [front] à `false` avant le maillage —
  /// les cristaux passent alors derrière la masse —, à `true` après.
  static void paint(
    Canvas canvas,
    Size size,
    SceneCamera camera, {
    required double seconds,
    required bool hero,
    required bool front,
  }) {
    // Échelle de référence : le plan du cœur. Les cristaux proches grossissent,
    // les lointains rapetissent, dans ce même rapport.
    final reference = camera.pixelsPerUnit(camera.z, size.height);
    final peak = (hero ? 0.52 : 0.34) * (front ? 1 : 0.75);

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
        1.5,
        _radius * size.shortestSide * state.size * (unit / reference),
      );
      _paintCrystal(
        canvas,
        Offset(point.sx, point.sy),
        radius,
        state.angle,
        _ice.withValues(alpha: (peak * state.opacity).clamp(0.0, 1.0)),
      );
    }
  }

  /// Un cristal : six branches barbelées, additives comme tout ce qui brille
  /// dans cette scène.
  static void _paintCrystal(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    Color color,
  ) {
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color
      // Le canevas est mis à l'échelle du cristal : l'épaisseur l'est aussi.
      // Le plancher garde le trait visible sur les plus petits.
      ..strokeWidth = math.max(0.1, 0.75 / radius);

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..scale(radius)
      ..drawPath(_crystal, paint)
      ..drawCircle(
        Offset.zero,
        0.16,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = color,
      )
      ..restore();
  }

  /// Silhouette du cristal, de rayon 1, construite une seule fois.
  static final Path _crystal = _buildCrystal();

  /// Position et longueur des barbes, en fraction de la branche.
  static const List<(double, double)> _barbs = [(0.42, 0.30), (0.70, 0.21)];
  static const double _barbAngle = 0.61;

  static Path _buildCrystal() {
    final path = Path();
    for (var arm = 0; arm < 6; arm++) {
      final a = arm * math.pi / 3;
      final dx = math.cos(a);
      final dy = math.sin(a);
      path
        ..moveTo(0, 0)
        ..lineTo(dx, dy);
      for (final (at, length) in _barbs) {
        final bx = dx * at;
        final by = dy * at;
        for (final side in const [1, -1]) {
          final b = a + side * _barbAngle;
          path
            ..moveTo(bx, by)
            ..lineTo(bx + math.cos(b) * length, by + math.sin(b) * length);
        }
      }
    }
    return path;
  }
}
