import 'dart:async';

import 'package:carlys_mobile/app/permissions/first_launch_permissions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_rest_alarm.dart';

void main() {
  late FakeRestAlarm alarm;
  late int cameraAsks;

  FirstLaunchPermissions service({bool askCamera = true}) =>
      FirstLaunchPermissions(
        alarm,
        askCamera: askCamera,
        requestCamera: () async => cameraAsks++,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    alarm = FakeRestAlarm();
    cameraAsks = 0;
  });

  test('premier lancement : notifications puis appareil photo', () async {
    await service().requestOnce();

    expect(alarm.calls, ['préparer']);
    expect(cameraAsks, 1);
  });

  test('lancements suivants : plus aucune demande', () async {
    await service().requestOnce();
    await service().requestOnce();

    expect(alarm.calls, ['préparer']);
    expect(cameraAsks, 1);
  });

  test(
    'sans demande d’appareil photo (iOS) : les notifications seules',
    () async {
      await service(askCamera: false).requestOnce();

      expect(alarm.calls, ['préparer']);
      expect(cameraAsks, 0);
    },
  );

  test('une panne de l’appareil photo ne remonte pas', () async {
    final failing = FirstLaunchPermissions(
      alarm,
      askCamera: true,
      requestCamera: () async => throw Exception('pas de caméra'),
    );
    await failing.requestOnce();

    expect(alarm.calls, ['préparer']);
  });

  test(
    'le drapeau est posé AVANT les boîtes : appli tuée, pas de boucle',
    () async {
      final pending = Completer<void>();
      final hanging = FirstLaunchPermissions(
        _HangingAlarm(pending.future),
        askCamera: false,
      );
      unawaited(hanging.requestOnce());
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(FirstLaunchPermissions.askedKey), isTrue);
      pending.complete();
    },
  );
}

/// Une boîte qui ne rend pas sa réponse : l'appli est tuée avant.
class _HangingAlarm extends FakeRestAlarm {
  _HangingAlarm(this._answer);

  final Future<void> _answer;

  @override
  Future<void> prepare() => _answer;
}
