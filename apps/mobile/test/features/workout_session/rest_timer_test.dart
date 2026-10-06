import 'package:carlys_mobile/features/workout_session/data/services/local_rest_alarm.dart';
import 'package:carlys_mobile/features/workout_session/presentation/controllers/workout_controllers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_rest_alarm.dart';

/// CE QUE CE FICHIER PROTÈGE : un repos juste après un écran éteint.
///
/// Écran noir, le téléphone suspend l'appli et ses minuteurs. Le repos se
/// décomptait d'une seconde par battement : rallumé après une minute, il
/// affichait encore « 1:29 » sur un repos d'une minute et demie.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('écran éteint une minute : le repos a bien avancé d’une minute', () {
    fakeAsync((async) {
      var now = DateTime(2026, 10, 5, 18);
      final alarm = FakeRestAlarm();
      final container = ProviderContainer(
        overrides: [
          restClockProvider.overrideWithValue(() => now),
          restAlarmProvider.overrideWithValue(alarm),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(restTimerProvider.notifier)
          .start(const Duration(seconds: 90));

      // Une minute passe SANS un seul battement (appli suspendue)…
      now = now.add(const Duration(minutes: 1));
      // … puis l'appli revit : un battement.
      async.elapse(const Duration(seconds: 1));
      expect(
        container.read(restTimerProvider)?.remaining,
        const Duration(seconds: 30),
      );

      // Le repos fini pendant l'écran noir s'arrête au premier battement.
      now = now.add(const Duration(minutes: 2));
      async.elapse(const Duration(seconds: 1));
      expect(container.read(restTimerProvider), isNull);
      // Le système a sonné la fin : le minuteur ne l'annule pas après coup.
      expect(alarm.calls, ['sonner dans 90 s']);
    });
  });

  test('« Passer » : la fin programmée ne sonnera pas', () {
    fakeAsync((async) {
      final alarm = FakeRestAlarm();
      final container = ProviderContainer(
        overrides: [restAlarmProvider.overrideWithValue(alarm)],
      );
      addTearDown(container.dispose);
      final timer = container.read(restTimerProvider.notifier)
        ..start(const Duration(seconds: 60));
      async.elapse(const Duration(seconds: 5));
      timer.stop();
      async.flushMicrotasks();
      expect(alarm.calls, ['sonner dans 60 s', 'annuler']);
      expect(container.read(restTimerProvider), isNull);
    });
  });
}
