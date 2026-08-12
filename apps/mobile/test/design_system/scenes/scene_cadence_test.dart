import 'package:carlys_mobile/design_system/scenes/scene_cadence.dart';
import 'package:flutter_test/flutter_test.dart';

/// La cadence adaptative : 30 i/s pour toujours sur un appareil à l'aise,
/// 20 puis 15 i/s quand la peinture déborde de son budget de temps, et
/// remontée — avec marge — quand l'appareil respire à nouveau.
void feed(SceneCadence cadence, Duration cost, int frames) {
  for (var i = 0; i < frames; i++) {
    cadence.reportPaintCost(cost);
  }
}

void main() {
  test('un appareil à l’aise reste à 30 i/s pour toujours', () {
    final cadence = SceneCadence();
    feed(cadence, const Duration(milliseconds: 3), 240);
    expect(cadence.framesPerSecond, 30);
  });

  test('une poignée d’images ne décide de rien (caches froids, GC)', () {
    final cadence = SceneCadence();
    feed(cadence, const Duration(milliseconds: 30), 5);
    expect(cadence.framesPerSecond, 30);
  });

  test('un pic isolé ne fait pas décrocher la cadence', () {
    final cadence = SceneCadence();
    feed(cadence, const Duration(milliseconds: 3), 30);
    feed(cadence, const Duration(milliseconds: 40), 1);
    feed(cadence, const Duration(milliseconds: 3), 30);
    expect(cadence.framesPerSecond, 30);
  });

  test('un téléphone qui peine descend à 20 i/s — et s’y stabilise', () {
    final cadence = SceneCadence();
    feed(cadence, const Duration(milliseconds: 12), 240);
    expect(cadence.framesPerSecond, 20);
  });

  test('un très vieux téléphone descend au plancher : 15 i/s', () {
    final cadence = SceneCadence();
    feed(cadence, const Duration(milliseconds: 25), 240);
    expect(cadence.framesPerSecond, 15);
  });

  test('la cadence REMONTE quand l’appareil respire à nouveau', () {
    final cadence = SceneCadence();
    feed(cadence, const Duration(milliseconds: 12), 120);
    expect(cadence.framesPerSecond, 20);

    feed(cadence, const Duration(milliseconds: 3), 240);
    expect(cadence.framesPerSecond, 30);
  });
}
