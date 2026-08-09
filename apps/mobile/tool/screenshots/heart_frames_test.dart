// Planche de contrôle du cœur : rend la scène à plusieurs instants du cycle
// pour vérifier ce qu'une capture d'écran ne montre pas — la dérive des
// particules, leur apparition en fondu, et la continuité au
// rebouclage (le cycle dure 30 s : l'image à 30 s doit être celle à 0 s).
//   flutter test tool/screenshots/heart_frames_test.dart --update-goldens
import 'package:carlys_mobile/design_system/scenes/heart_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final seconds in const [0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 21.0, 30.0]) {
    testWidgets('cœur à ${seconds}s', (tester) async {
      tester.view.physicalSize = const Size(990, 990);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: ColoredBox(
            color: const Color(0xFF06060C),
            child: CustomPaint(
              painter: HeartScenePainter(seconds: seconds, hero: false),
              size: const Size(330, 330),
            ),
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(CustomPaint).last,
        matchesGoldenFile('goldens/coeur-${seconds.toStringAsFixed(1)}.png'),
      );
    });
  }
}
