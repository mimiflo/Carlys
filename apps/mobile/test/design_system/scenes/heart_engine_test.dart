import 'dart:async';

import 'package:carlys_mobile/design_system/scenes/heart_engine.dart';
import 'package:carlys_mobile/design_system/scenes/heart_frame.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le moteur du cœur calcule ses images dans un isolate. L'écran de
/// démarrage le lance D'AVANCE ([HeartEngine.prewarm]) : le premier cœur de
/// l'accueil l'adopte au lieu d'attendre le sien, temps pendant lequel le
/// peintre calculait seul, sur le fil d'interface.
void main() {
  const request = HeartFrameRequest(
    seconds: 1,
    hero: true,
    still: false,
    width: 240,
    height: 240,
  );

  /// Temps jusqu'à la première image calculée par l'isolate.
  Future<Duration> firstFrame(HeartEngine engine) async {
    final watch = Stopwatch()..start();
    final arrived = Completer<void>();
    engine.latest.addListener(() {
      if (!arrived.isCompleted) arrived.complete();
    });
    engine.request(request);
    await arrived.future.timeout(const Duration(seconds: 10));
    return watch.elapsed;
  }

  test('un moteur adopte l’isolate préparé, et en rend les images', () async {
    // Un premier calcul pour chauffer le code (partagé entre isolates) :
    // sinon la première mesure paie la compilation, quelle qu'elle soit.
    final jit = HeartEngine();
    await firstFrame(jit);
    jit.dispose();

    // Sans préparation : le moteur lance le sien à la première demande.
    expect(HeartEngine.hasSpare, isFalse);
    final cold = HeartEngine();
    addTearDown(cold.dispose);
    final spawned = await firstFrame(cold);

    HeartEngine.prewarm();
    expect(HeartEngine.hasSpare, isTrue);
    // Le plancher de l'écran de démarrage : l'isolate a le temps de naître.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final warm = HeartEngine();
    addTearDown(warm.dispose);
    final adopted = await firstFrame(warm);
    // ADOPTÉ par la première demande : plus d'isolate en attente.
    expect(HeartEngine.hasSpare, isFalse);

    expect(warm.latest.value, isNotNull);
    expect(cold.latest.value, isNotNull);
    // Mesuré le 18 octobre 2026 (mode debug) : 7 à 10 ms préparé, 40 à
    // 75 ms à froid. Pas d'assertion sur la durée — une machine de CI
    // chargée la rendrait aléatoire ; la mesure est rendue au journal.
    printOnFailure('première image : préparé $adopted, à froid $spawned');
  });
}
