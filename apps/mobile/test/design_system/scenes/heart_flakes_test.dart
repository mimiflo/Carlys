import 'dart:ui';

import 'package:carlys_mobile/design_system/scenes/heart_flakes.dart';
import 'package:carlys_mobile/design_system/scenes/scene3d.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cristaux de givre autour du cœur.
///
/// Ce qu'on vérifie ici, c'est le MODÈLE — position, vie, opacité — parce que
/// c'est là que sont les pièges : un cycle qui ne boucle pas téléporte les
/// cristaux toutes les trente secondes, et un vivier mal égrené les fait tous
/// apparaître ensemble, ce qui n'est plus un accent mais une tempête.
void main() {
  SceneCamera cameraOf() => SceneCamera(
        fovDegrees: 32,
        x: 0.1,
        y: 0.15,
        z: 7.4,
        targetX: 0,
        targetY: -0.05,
        targetZ: 0,
      );

  /// Cristaux effectivement visibles à un instant donné.
  int visibleAt(double seconds) {
    var visible = 0;
    for (var i = 0; i < HeartFlakes.count; i++) {
      final state = HeartFlakes.stateAt(i, seconds);
      if (state != null && state.opacity > 0.02) {
        visible++;
      }
    }
    return visible;
  }

  test('le cycle boucle sans le moindre saut', () {
    // La scène rejoue sa boucle toutes les trente secondes. Si l'état à 30 s
    // différait de l'état à 0, chaque cristal se téléporterait à cet instant —
    // le défaut le plus visible qui soit sur un élément qui dérive lentement.
    //
    // L'égalité se mesure à une tolérance serrée, PAS au bit près : le tour de
    // cycle passe par un `% 1` sur `1 + décalage`, dont le dernier bit diffère
    // de celui de `0 + décalage`. Un vrai saut vaudrait un dixième de cadre ;
    // ce qu'on tolère ici est mille millions de fois plus petit.
    for (var i = 0; i < HeartFlakes.count; i++) {
      final looped = HeartFlakes.stateAt(i, HeartFlakes.cycle);
      final origin = HeartFlakes.stateAt(i, 0);
      expect(looped == null, origin == null, reason: 'cristal $i');
      if (looped == null || origin == null) {
        continue;
      }
      expect(looped.across, closeTo(origin.across, 1e-9), reason: 'cristal $i');
      expect(looped.fall, closeTo(origin.fall, 1e-9), reason: 'cristal $i');
      expect(looped.angle, closeTo(origin.angle, 1e-9), reason: 'cristal $i');
      expect(
        looped.opacity,
        closeTo(origin.opacity, 1e-9),
        reason: 'cristal $i',
      );
    }

    // Et la continuité vaut aussi juste AVANT le rebouclage.
    for (var i = 0; i < HeartFlakes.count; i++) {
      final before = HeartFlakes.stateAt(i, HeartFlakes.cycle - 0.02);
      final after = HeartFlakes.stateAt(i, 0.02);
      if (before == null || after == null) {
        continue;
      }
      expect((before.fall - after.fall).abs(), lessThan(0.02));
    }
  });

  test('le rendu est déterministe', () {
    expect(HeartFlakes.stateAt(3, 12.5), HeartFlakes.stateAt(3, 12.5));
  });

  test('de temps en temps : jamais tous ensemble, jamais le vide complet', () {
    var least = HeartFlakes.count;
    var most = 0;
    for (var step = 0; step < 600; step++) {
      final visible = visibleAt(step * HeartFlakes.cycle / 600);
      least = least < visible ? least : visible;
      most = most > visible ? most : visible;
    }

    // Un accent : quelques cristaux, jamais la moitié du vivier.
    expect(most, lessThanOrEqualTo(HeartFlakes.count ~/ 2));
    // Mais jamais rien non plus : la page ne doit pas paraître morte.
    expect(least, greaterThanOrEqualTo(1));
  });

  test('un cristal naît et meurt en fondu', () {
    expect(HeartFlakes.envelope(0), 0);
    expect(HeartFlakes.envelope(1), 0);
    expect(HeartFlakes.envelope(0.5), 1);
    // Croissante sur la montée.
    expect(HeartFlakes.envelope(0.05), lessThan(HeartFlakes.envelope(0.12)));
  });

  test('aucun cristal ne traverse la masse du cœur', () {
    // Sans tampon de profondeur, un cristal dans le volume du cœur serait
    // dessiné soit entièrement devant, soit entièrement derrière — donc faux
    // la moitié du temps. La bande est interdite, et ça se vérifie.
    for (var i = 0; i < HeartFlakes.count; i++) {
      final z = HeartFlakes.depthOf(i);
      expect(
        z <= HeartFlakes.behindZ || z >= HeartFlakes.frontZ,
        isTrue,
        reason: 'cristal $i à z=$z',
      );
    }
  });

  test('la moitié du vivier passe devant, l\'autre derrière', () {
    final front = List.generate(HeartFlakes.count, HeartFlakes.isInFront)
        .where((f) => f)
        .length;
    expect(front, HeartFlakes.count ~/ 2);
  });

  test('les cristaux descendent', () {
    // Le sens de la chute : haut → bas, comme la neige.
    final start = HeartFlakes.stateAt(0, 0.2);
    final later = HeartFlakes.stateAt(0, 4);
    expect(start, isNotNull);
    expect(later, isNotNull);
    expect(later!.fall, lessThan(start!.fall));
  });

  test('chaque passe ne dessine que son propre plan', () {
    // Le tri par plan n'est pas cosmétique : c'est lui qui fait passer des
    // cristaux DEVANT le cœur et d'autres derrière.
    const seconds = 6.0;
    final camera = cameraOf();

    final front = _Tally();
    HeartFlakes.paint(
      front,
      const Size(330, 330),
      camera,
      seconds: seconds,
      hero: false,
      front: true,
    );
    final behind = _Tally();
    HeartFlakes.paint(
      behind,
      const Size(330, 330),
      camera,
      seconds: seconds,
      hero: false,
      front: false,
    );

    var expectedFront = 0;
    var expectedBehind = 0;
    for (var i = 0; i < HeartFlakes.count; i++) {
      final state = HeartFlakes.stateAt(i, seconds);
      if (state == null || state.opacity <= 0) {
        continue;
      }
      if (HeartFlakes.isInFront(i)) {
        expectedFront++;
      } else {
        expectedBehind++;
      }
    }

    expect(front.paths, expectedFront);
    expect(behind.paths, expectedBehind);
    // Les deux plans sont peuplés : sans ça, l'effet de profondeur n'existe
    // pas et le test précédent passerait sur un vivier tout entier d'un côté.
    expect(front.paths, greaterThan(0));
    expect(behind.paths, greaterThan(0));
  });

  test('un cristal reste dans le cadre de la scène', () {
    // Un cristal projeté hors du canevas serait du travail perdu : le
    // conteneur découpe. La position est exprimée en demi-cadres à SA
    // profondeur, ce qui doit garantir qu'elle survit à la projection.
    const size = Size(330, 330);
    final camera = cameraOf();
    final tally = _Bounds();
    for (var step = 0; step < 120; step++) {
      HeartFlakes.paint(
        tally,
        size,
        camera,
        seconds: step * HeartFlakes.cycle / 120,
        hero: true,
        front: true,
      );
    }
    expect(tally.minX, greaterThan(-size.width * 0.1));
    expect(tally.maxX, lessThan(size.width * 1.1));
    expect(tally.minY, greaterThan(-size.height * 0.1));
    expect(tally.maxY, lessThan(size.height * 1.1));
  });
}

/// Canevas de comptage : `noSuchMethod` absorbe tout le reste de l'interface.
class _Tally implements Canvas {
  int paths = 0;

  @override
  void drawPath(Path path, Paint paint) => paths++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Canevas qui relève l'emprise des cristaux (chaque `translate` est un
/// cristal, puisque la pile est repositionnée pour chacun).
class _Bounds implements Canvas {
  double minX = double.infinity;
  double maxX = double.negativeInfinity;
  double minY = double.infinity;
  double maxY = double.negativeInfinity;

  @override
  void translate(double dx, double dy) {
    minX = dx < minX ? dx : minX;
    maxX = dx > maxX ? dx : maxX;
    minY = dy < minY ? dy : minY;
    maxY = dy > maxY ? dy : maxY;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
