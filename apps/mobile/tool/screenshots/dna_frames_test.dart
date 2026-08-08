// Planche de contrôle de l'hélice : rend la scène à plusieurs instants de
// rotation pour traquer les artefacts qui n'apparaissent qu'en mouvement.
//   flutter test tool/screenshots/dna_frames_test.dart --update-goldens
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:carlys_mobile/design_system/scenes/dna_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final seconds in const [0.0, 1.7, 3.4, 5.1, 6.8, 8.5]) {
    testWidgets('hélice à ${seconds}s', (tester) async {
      tester.view.physicalSize = const Size(1080, 1080);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: ColoredBox(
            color: const Color(0xFF06060C),
            child: CustomPaint(
              painter: DnaScenePainter(time: seconds),
              size: const Size(360, 360),
            ),
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(CustomPaint).last,
        matchesGoldenFile('goldens/dna-${seconds.toStringAsFixed(1)}.png'),
      );
    });
  }
}
