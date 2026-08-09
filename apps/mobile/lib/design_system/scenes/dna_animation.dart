import 'dart:math' as math;
import 'dart:typed_data';

import 'dna_mesh.dart';

/// Ce qui bouge dans la double hélice : rotation, respiration, écartement des
/// barreaux — isolé du rendu pour être vérifiable.
///
/// **Tout est une harmonique du tour de rotation.** L'animation rejoue son
/// cycle en boucle : si une composante ne repasse pas exactement par sa valeur
/// de départ à la fin du tour, elle saute d'un coup à chaque rebouclage. La
/// maquette battait à 0,65 et 1,40 rad/s pour une rotation à 0,22 : soit 2,95
/// et 6,36 cycles par tour, donc un saut toutes les 28 secondes. On garde les
/// mêmes allures en arrondissant les rapports à l'entier le plus proche — 3 et
/// 6 — ce qui déplace la respiration de 1,5 % et la pulsation de 5,7 %, deux
/// écarts qu'aucun œil ne relève, contre un saut que tout le monde voit.
class DnaAnimation {
  const DnaAnimation._();

  /// Vitesse de rotation de la maquette (rad/s).
  static const double spin = 0.22;

  /// Durée d'un tour complet, donc du cycle entier.
  static const double cycleSeconds = 2 * math.pi / spin;

  /// Respiration globale : 3 cycles par tour (maquette : 0,65 rad/s).
  static const double breathRate = 3 * spin;

  /// Pulsation des barreaux : 6 cycles par tour (maquette : 1,40 rad/s).
  static const double rungRate = 6 * spin;

  /// Pose de la scène à un instant donné.
  static DnaPose poseAt(double time) {
    final breathPhase = math.sin(time * breathRate);
    final rungScale = Float64List(DnaMesh.rungCount);
    for (var i = 0; i < DnaMesh.rungCount; i++) {
      final pulse = 0.5 + 0.5 * math.sin(time * rungRate - DnaMesh.rungPhases[i]);
      rungScale[i] = 0.985 + pulse * 0.03;
    }
    return DnaPose(
      spinY: time * spin,
      breath: 1 + breathPhase * 0.03,
      breathY: 1 + breathPhase * 0.008,
      rungScale: rungScale,
    );
  }
}

/// État figé de l'hélice à un instant.
class DnaPose {
  const DnaPose({
    required this.spinY,
    required this.breath,
    required this.breathY,
    required this.rungScale,
  });

  /// Angle de rotation autour de Y (radians).
  final double spinY;

  /// Échelle radiale de la respiration.
  final double breath;

  /// Échelle verticale de la respiration (bien plus discrète).
  final double breathY;

  /// Écartement propre à chaque barreau.
  final Float64List rungScale;
}
