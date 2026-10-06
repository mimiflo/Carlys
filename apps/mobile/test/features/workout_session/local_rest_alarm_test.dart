import 'dart:async';

import 'package:carlys_mobile/features/workout_session/data/services/local_rest_alarm.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

/// Le greffon, sans plateforme : il note ce qu'on lui demande.
class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final List<tz.TZDateTime> scheduled = [];
  int initializations = 0;
  Completer<void>? initGate;
  Object? initFailure;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializations++;
    await initGate?.future;
    final failure = initFailure;
    if (failure != null) {
      initFailure = null;
      throw failure;
    }
    return true;
  }

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async => scheduled.add(scheduledDate);

  @override
  Future<void> cancel({required int id, String? tag}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('un repos de zéro seconde ne programme rien, sans erreur', () async {
    final plugin = _FakePlugin();
    await LocalRestAlarm(plugin).schedule(Duration.zero);
    expect(plugin.scheduled, isEmpty);
  });

  test(
    'l’heure de fin ne recule pas du temps passé sur la permission',
    () async {
      final plugin = _FakePlugin()..initGate = Completer<void>();
      final avant = DateTime.now();
      final programme = LocalRestAlarm(
        plugin,
      ).schedule(const Duration(seconds: 90));
      // La personne lit la demande de permission…
      await Future<void>.delayed(const Duration(milliseconds: 400));
      plugin.initGate!.complete();
      await programme;

      final fin = plugin.scheduled.single;
      final attendu = avant.add(const Duration(seconds: 90));
      expect(
        fin.difference(attendu).inMilliseconds.abs(),
        lessThan(200),
        reason: 'la fin compte depuis le début du repos, pas depuis la réponse',
      );
    },
  );

  test('une initialisation ratée est retentée au repos suivant', () async {
    final plugin = _FakePlugin()
      ..initFailure = PlatformException(code: 'refus');
    final alarm = LocalRestAlarm(plugin);

    await alarm.schedule(const Duration(seconds: 60));
    expect(plugin.scheduled, isEmpty);

    await alarm.schedule(const Duration(seconds: 60));
    expect(plugin.initializations, 2);
    expect(plugin.scheduled, hasLength(1));
  });
}
