import 'dart:async';

import 'package:carlys_mobile/design_system/scenes/heart_engine.dart';
import 'package:carlys_mobile/design_system/scenes/heart_frame.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le calcul d'image du cœur : pur, déterministe, et identique quel que soit
/// le fil qui l'exécute — c'est ce qui autorise le repli synchrone du peintre
/// (tests, planche de contrôle, première image) sans changer un pixel.
void main() {
  const request = HeartFrameRequest(
    seconds: 3.7,
    hero: true,
    still: false,
    width: 240,
    height: 240,
  );

  test('le même instant produit exactement les mêmes tampons', () {
    final a = computeHeartFrame(request);
    final b = computeHeartFrame(request);

    expect(a.beat, b.beat);
    expect(a.bob, b.bob);
    expect(a.screen, equals(b.screen));
    expect(a.colors, equals(b.colors));
    expect(a.indices, equals(b.indices));
    expect(a.wide, equals(b.wide));
    expect(a.coreColors, equals(b.coreColors));
    expect(a.coreIndices, equals(b.coreIndices));
  });

  test('une image contient un maillage et son voile interne', () {
    final frame = computeHeartFrame(request);

    // Des faces avant existent, par triangles entiers, et chaque indice
    // pointe dans le tampon de sommets.
    expect(frame.indices, isNotEmpty);
    expect(frame.indices.length % 3, 0);
    expect(frame.coreIndices, isNotEmpty);
    expect(frame.coreIndices.length % 3, 0);
    final vertexCount = frame.screen.length ~/ 2;
    for (final index in frame.indices) {
      expect(index, lessThan(vertexCount));
    }
    expect(frame.colors.length, vertexCount);
    expect(frame.wide.length, frame.screen.length);
  });

  test('la pose figée est une diastole franche', () {
    final frame = computeHeartFrame(
      const HeartFrameRequest(
        seconds: 0,
        hero: false,
        still: true,
        width: 240,
        height: 240,
      ),
    );
    expect(frame.beat, 0);
  });

  test('l\'isolate livre une image conforme à la demande', () async {
    final engine = HeartEngine();
    final delivered = Completer<HeartFrame>();
    engine.latest.addListener(() {
      final frame = engine.latest.value;
      if (frame != null && !delivered.isCompleted) {
        delivered.complete(frame);
      }
    });

    engine.request(request);
    final frame = await delivered.future.timeout(const Duration(seconds: 30));

    expect(frame.seconds, request.seconds);
    expect(frame.hero, request.hero);
    expect(frame.width, request.width);
    expect(frame.height, request.height);
    // Et c'est bien la même image que le calcul local : mêmes mathématiques,
    // mêmes pixels, quel que soit le fil.
    expect(frame.screen, equals(computeHeartFrame(request).screen));

    engine.dispose();
  });

  test('les demandes se coalescent : seule la plus récente est calculée',
      () async {
    final engine = HeartEngine();
    final frames = <HeartFrame>[];
    final done = Completer<void>();
    engine.latest.addListener(() {
      final frame = engine.latest.value;
      if (frame == null) {
        return;
      }
      frames.add(frame);
      if (frame.seconds == 20 && !done.isCompleted) {
        done.complete();
      }
    });

    // Vingt-et-une demandes avant même que l'isolate soit prêt : une seule
    // image doit sortir, celle de la dernière demande.
    for (var i = 0; i <= 20; i++) {
      engine.request(
        HeartFrameRequest(
          seconds: i.toDouble(),
          hero: false,
          still: false,
          width: 240,
          height: 240,
        ),
      );
    }
    await done.future.timeout(const Duration(seconds: 30));

    expect(frames, hasLength(1));
    expect(frames.single.seconds, 20);

    engine.dispose();
  });
}
