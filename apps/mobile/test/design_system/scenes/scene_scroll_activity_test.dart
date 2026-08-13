import 'package:carlys_mobile/design_system/scenes/heart_scene.dart';
import 'package:carlys_mobile/design_system/scenes/scene_scroll_activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pendant qu'on FAIT DÉFILER, les scènes se figent — chaque image du cœur
/// coûte des millisecondes de fil d'interface, exactement le budget qui
/// manquait au défilement sur un téléphone modeste. À l'arrêt, l'animation
/// reprend, et le temps de scène ne revient JAMAIS en arrière.
HeartScenePainter painterOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is HeartScenePainter,
    ),
  );
  return paint.painter! as HeartScenePainter;
}

Widget host() => MaterialApp(
      home: Scaffold(
        body: SceneScrollActivity(
          child: ListView(
            children: [
              const SizedBox(height: 320, child: HeartScene()),
              for (var i = 0; i < 20; i++) const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('le cœur se fige pendant le défilement, reprend sans reculer',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 400));
    expect(painterOf(tester).seconds, greaterThan(0));

    // Doigt posé, défilement en cours : le temps de scène S'ARRÊTE.
    final gesture = await tester.startGesture(const Offset(200, 500));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    final frozen = painterOf(tester).seconds;

    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 400));
    expect(painterOf(tester).seconds, frozen);

    // Doigt levé, inertie terminée : ça repart — jamais en arrière.
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    final resumed = painterOf(tester).seconds;
    expect(resumed, greaterThan(frozen));
  });

  testWidgets('hors de toute portée SceneScrollActivity, rien ne change',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(height: 320, child: HeartScene())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final before = painterOf(tester).seconds;
    await tester.pump(const Duration(milliseconds: 400));
    expect(painterOf(tester).seconds, greaterThan(before));
  });
}
