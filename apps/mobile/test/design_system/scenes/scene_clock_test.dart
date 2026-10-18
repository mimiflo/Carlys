import 'package:carlys_mobile/design_system/scenes/scene_clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'horloge des scènes : un pas par image de scène, un temps qui ne
/// recule ni ne saute, et le silence quand l'application n'est plus vue.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // Hors `testWidgets`, le banc n'a pas d'état de cycle de vie : on pose
  // celui d'une application au premier plan, où les images sont permises.
  setUp(
    () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
  );

  test('un pas toutes les 33 ms, au temps exact du pas', () {
    fakeAsync((async) {
      final steps = <double>[];
      final clock = SceneClock(framesPerSecond: () => 30, onStep: steps.add)
        ..start();

      async.elapse(const Duration(milliseconds: 330));
      clock.dispose();

      expect(steps, hasLength(10));
      for (final (index, seconds) in steps.indexed) {
        expect(seconds, closeTo((index + 1) * 0.033, 1e-9));
      }
    });
  });

  test('arrêtée puis relancée, elle repart d’où elle s’était arrêtée', () {
    fakeAsync((async) {
      final clock = SceneClock(framesPerSecond: () => 30, onStep: (_) {})
        ..start();
      async.elapse(const Duration(milliseconds: 99));
      clock.stop();
      final frozen = clock.seconds;

      // Une pause longue : le temps de scène, lui, ne bouge pas.
      async.elapse(const Duration(seconds: 5));
      expect(clock.seconds, frozen);

      clock.start();
      async.elapse(const Duration(milliseconds: 33));
      expect(clock.seconds, closeTo(frozen + 0.033, 1e-9));
      clock.dispose();
    });
  });

  test('la cadence change sans saut ni recul du temps', () {
    fakeAsync((async) {
      var fps = 30.0;
      final steps = <double>[];
      final clock = SceneClock(framesPerSecond: () => fps, onStep: steps.add)
        ..start();
      async.elapse(const Duration(milliseconds: 165));
      fps = 20; // L'appareil peine : la scène descend d'un palier.
      async.elapse(const Duration(seconds: 1));
      clock.dispose();

      for (var i = 1; i < steps.length; i++) {
        final gap = steps[i] - steps[i - 1];
        expect(gap, greaterThan(0), reason: 'pas $i : le temps recule');
        // Jamais plus d'un pas de la cadence la plus lente (50 ms).
        expect(gap, lessThanOrEqualTo(0.05 + 1e-9), reason: 'pas $i : saut');
      }
      // Passé le changement, les pas sont ceux de 20 i/s.
      expect(steps.last - steps[steps.length - 2], closeTo(0.05, 1e-9));
    });
  });

  test('application en arrière-plan : plus aucun pas, reprise sans saut', () {
    fakeAsync((async) {
      final steps = <double>[];
      final clock = SceneClock(framesPerSecond: () => 30, onStep: steps.add)
        ..start();
      async.elapse(const Duration(milliseconds: 99));
      final before = steps.length;

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      async.elapse(const Duration(seconds: 10));
      expect(steps, hasLength(before), reason: 'écran éteint, aucun pas');

      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      async.elapse(const Duration(milliseconds: 33));
      expect(steps, hasLength(before + 1));
      // Les dix secondes d'arrière-plan ne comptent pas dans la scène.
      expect(steps.last, closeTo(0.099 + 0.033, 1e-9));
      clock.dispose();
    });
  });
}
