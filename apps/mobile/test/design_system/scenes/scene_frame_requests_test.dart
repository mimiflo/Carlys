import 'package:carlys_mobile/design_system/scenes/heart_scene.dart';
import 'package:carlys_mobile/design_system/scenes/heart_scene_painter.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/dna_helix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les scènes 3D se rendent à 30 i/s : elles ne doivent DEMANDER une image
/// qu'à chaque nouvelle image de scène. Un `Ticker` en demandait une à
/// chaque battement d'écran — 120 par seconde sur un écran 120 Hz, dont
/// trois sur quatre ne changeaient rien, et autant de réveils du moteur.
///
/// Le banc imite l'écran : à chaque battement de 1/120 s, le temps avance,
/// et une image n'est dessinée QUE si quelqu'un l'a demandée.
Future<int> framesRequestedOver(WidgetTester tester, Duration total) async {
  const vsync = Duration(microseconds: 8333);
  var frames = 0;
  for (var t = Duration.zero; t < total; t += vsync) {
    await tester.binding.delayed(vsync);
    if (tester.binding.hasScheduledFrame) {
      frames++;
      await tester.pump();
    }
  }
  return frames;
}

void main() {
  // Cinq secondes à 30 i/s : 150 images de scène, plus une marge d'arrondi.
  const fiveSeconds = Duration(seconds: 5);
  const ceiling = 5 * 30 + 5;

  testWidgets('le cœur ne demande une image que pour une image de scène', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(width: 240, height: 240, child: HeartScene()),
      ),
    );
    final frames = await framesRequestedOver(tester, fiveSeconds);
    expect(frames, lessThanOrEqualTo(ceiling));
    expect(frames, greaterThan(100), reason: 'le cœur bat toujours');
  });

  testWidgets('l’hélice ne demande une image que pour une image de scène', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DnaHelix()));
    final frames = await framesRequestedOver(tester, fiveSeconds);
    expect(frames, lessThanOrEqualTo(ceiling));
    expect(frames, greaterThan(100), reason: 'l’hélice tourne toujours');
  });

  testWidgets('hors de l’écran (TickerMode éteint), le cœur ne demande rien', (
    tester,
  ) async {
    // Un onglet caché, une route recouverte : le `Ticker` s'y taisait seul,
    // l'horloge doit le faire aussi.
    await tester.pumpWidget(
      const MaterialApp(
        home: TickerMode(
          enabled: false,
          child: SizedBox(width: 240, height: 240, child: HeartScene()),
        ),
      ),
    );
    // L'image de mise en place passée, plus rien ne doit être demandé.
    await tester.pump();
    expect(await framesRequestedOver(tester, fiveSeconds), 0);
  });

  testWidgets('application en arrière-plan : le cœur se tait, puis reprend '
      'sans sauter', (tester) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(width: 240, height: 240, child: HeartScene()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final before = heartSeconds(tester);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // Écran éteint : le banc ne dessine rien, et la scène ne compte rien —
    // pas de pas, donc aucune demande à l'isolate non plus.
    await tester.binding.delayed(const Duration(seconds: 10));
    expect(tester.binding.hasScheduledFrame, isFalse);

    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 300));
    final after = heartSeconds(tester);
    expect(after, greaterThan(before), reason: 'le cœur bat de nouveau');
    // Les dix secondes d'arrière-plan n'entrent pas dans le temps de scène.
    expect(after - before, lessThan(1));
  });
}

double heartSeconds(WidgetTester tester) =>
    (tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is CustomPaint &&
                        widget.painter is HeartScenePainter,
                  ),
                )
                .painter!
            as HeartScenePainter)
        .seconds;
