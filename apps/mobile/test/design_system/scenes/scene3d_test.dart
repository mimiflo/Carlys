import 'dart:typed_data';

import 'package:carlys_mobile/design_system/scenes/scene3d.dart';
import 'package:flutter_test/flutter_test.dart';

/// `projectInto` (boucle de sommets, sans allocation) doit projeter
/// EXACTEMENT comme `project` : c'est la même caméra, seule la forme du
/// résultat change. Toute divergence déformerait le maillage.
void main() {
  test('projectInto et project rendent exactement les mêmes coordonnées', () {
    final camera = SceneCamera(
      fovDegrees: 32,
      x: 0.1,
      y: 0.15,
      z: 7.4,
      targetX: 0,
      targetY: -0.05,
      targetZ: 0,
    );
    const width = 330.0;
    const height = 330.0;

    const points = [
      (0.0, 0.0, 0.0),
      (1.05, -0.9, 0.86),
      (-1.2, 1.4, -0.7),
      (0.3, 0.0, 6.9), // Presque sur la caméra : le garde-fou de profondeur.
    ];

    final screen = Float32List(points.length * 2);
    final depth = Float32List(points.length);

    for (var i = 0; i < points.length; i++) {
      final (px, py, pz) = points[i];
      camera.projectInto(screen, depth, i, px, py, pz, width, height);
      final expected = camera.project(px, py, pz, width, height);

      expect(screen[i * 2], moreOrLessEquals(expected.sx, epsilon: 1e-3));
      expect(screen[i * 2 + 1], moreOrLessEquals(expected.sy, epsilon: 1e-3));
      expect(depth[i], moreOrLessEquals(expected.viewZ, epsilon: 1e-6));
    }
  });
}
