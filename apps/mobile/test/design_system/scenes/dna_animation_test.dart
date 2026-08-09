import 'package:carlys_mobile/design_system/scenes/dna_animation.dart';
import 'package:carlys_mobile/design_system/scenes/dna_mesh.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'hélice rejoue son cycle en boucle : ce qui compte, c'est que la fin du
/// tour retombe exactement sur son début. Sinon la scène saute une fois toutes
/// les vingt-huit secondes — discret, mais visible dès qu'on regarde.
void main() {
  test('le tour boucle : rien ne saute au rebouclage', () {
    final start = DnaAnimation.poseAt(0);
    final end = DnaAnimation.poseAt(DnaAnimation.cycleSeconds);

    // Tolérance serrée mais pas au bit près : `sin(2π k)` ne rend pas zéro
    // exact. Un vrai saut vaudrait des millièmes ; on tolère un milliardième.
    expect(end.breath, closeTo(start.breath, 1e-9));
    expect(end.breathY, closeTo(start.breathY, 1e-9));
    for (var i = 0; i < DnaMesh.rungCount; i++) {
      expect(
        end.rungScale[i],
        closeTo(start.rungScale[i], 1e-9),
        reason: 'barreau $i',
      );
    }
  });

  test('la rotation vaut exactement un tour sur le cycle', () {
    final end = DnaAnimation.poseAt(DnaAnimation.cycleSeconds);

    expect(end.spinY, closeTo(2 * 3.141592653589793, 1e-12));
  });

  test('respiration et pulsation sont des harmoniques entières du tour', () {
    // C'est la propriété qui GARANTIT le rebouclage, pour toute vitesse de
    // rotation : la vérifier ici, c'est protéger le jour où `spin` changera.
    final breathCycles = DnaAnimation.breathRate / DnaAnimation.spin;
    final rungCycles = DnaAnimation.rungRate / DnaAnimation.spin;

    expect(breathCycles, closeTo(breathCycles.roundToDouble(), 1e-12));
    expect(rungCycles, closeTo(rungCycles.roundToDouble(), 1e-12));
  });

  test('les allures restent celles de la maquette, à quelques pour cent', () {
    // Le correctif déplace les fréquences ; il ne doit pas changer l'aspect.
    expect(DnaAnimation.breathRate, closeTo(0.65, 0.65 * 0.05));
    expect(DnaAnimation.rungRate, closeTo(1.4, 1.4 * 0.08));
  });

  test('l’écartement des barreaux reste dans sa plage', () {
    for (final t in const [0.0, 3.3, 11.7, 20.4, 28.0]) {
      final pose = DnaAnimation.poseAt(t);
      for (var i = 0; i < DnaMesh.rungCount; i++) {
        expect(pose.rungScale[i], inInclusiveRange(0.985, 1.015));
      }
      expect(pose.breath, inInclusiveRange(0.97, 1.03));
      expect(pose.breathY, inInclusiveRange(0.992, 1.008));
    }
  });
}
