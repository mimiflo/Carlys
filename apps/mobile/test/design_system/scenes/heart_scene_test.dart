import 'package:carlys_mobile/design_system/scenes/heart_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le temps de la scène du cœur.
void main() {
  double timeOf(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(HeartScene),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    return (paint.painter! as HeartScenePainter).seconds;
  }

  Future<void> pumpScene(WidgetTester tester, {bool reduceMotion = false}) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const SizedBox(width: 240, height: 240, child: HeartScene()),
        ),
      ),
    );
  }

  testWidgets('le temps ne revient jamais en arrière', (tester) async {
    // Le piège : une boucle de trente secondes ramenait le temps à zéro, et
    // comme aucune période de la scène ne divise le tour — rotation, ballant,
    // battement à 57 bpm — tout sautait ensemble une fois par tour.
    await pumpScene(tester);

    var previous = timeOf(tester);
    for (var second = 0; second < 40; second++) {
      await tester.pump(const Duration(seconds: 1));
      final now = timeOf(tester);
      expect(now, greaterThanOrEqualTo(previous), reason: 'à ${second}s');
      previous = now;
    }

    // Bien au-delà de l'ancien tour : c'est là que le saut se produisait.
    expect(previous, greaterThan(30));
  });

  testWidgets('la scène se fige sous réduction d\'animations', (tester) async {
    // Une scène qui continue de tourner empêche toute stabilisation — et
    // c'est d'abord une question d'accessibilité.
    await pumpScene(tester, reduceMotion: true);
    await tester.pump(const Duration(seconds: 5));

    expect(timeOf(tester), 0);
    await tester.pumpAndSettle();
  });
}
