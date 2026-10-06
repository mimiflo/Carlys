import 'dart:io' show Platform;

import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/logging/app_logger.dart';
import '../../domain/services/rest_alarm.dart';

/// La fin de repos confiée au SYSTÈME, par une notification programmée
/// (`flutter_local_notifications`, la passerelle standard : MIT, sans
/// service tiers ni compte).
///
/// Sur Android, l'heure est exacte si le système le permet (permission
/// d'alarme exacte, accordée d'office jusqu'à Android 13) ; sinon elle peut
/// glisser de quelques secondes à quelques minutes, ce qui vaut toujours
/// mieux que le silence. L'heure est en UTC : un délai ne dépend d'aucun
/// fuseau, et la base des fuseaux n'a pas à être chargée.
///
/// Une panne du greffon (permission refusée, plateforme sans greffon) ne
/// casse jamais le repos : elle se journalise, et le minuteur à l'écran
/// reste juste.
class LocalRestAlarm implements RestAlarm {
  LocalRestAlarm([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const _logger = AppLogger('LocalRestAlarm');

  /// Une seule notification de repos à la fois : la suivante remplace.
  static const _id = 7301;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'carlys_rest_end',
      'Fin du repos',
      channelDescription: 'Sonne quand le repos entre deux séries est fini.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    ),
    iOS: DarwinNotificationDetails(presentSound: true, presentBanner: true),
  );

  Future<void>? _ready;

  /// Initialisation et permission, UNE fois, au premier repos : c'est là que
  /// la demande a un sens pour la personne. Ratée, elle sera retentée au
  /// repos suivant plutôt que de condamner tous les autres.
  Future<void> _prepare() async {
    final ready = _ready ??= _initialize();
    try {
      await ready;
    } catch (_) {
      _ready = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_rest'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
  }

  @override
  Future<void> schedule(Duration after) => _guard('programmée', () async {
    // L'heure de fin se fixe AVANT la demande de permission : au premier
    // repos, le temps passé à y répondre ne doit pas retarder la fin.
    final endsAt = tz.TZDateTime.now(tz.UTC).add(after);
    if (after <= Duration.zero) return;
    await _prepare();
    // Une réponse plus longue que le repos : il est fini, rien à sonner
    // (le système refuserait d'ailleurs une heure passée).
    if (!endsAt.isAfter(tz.TZDateTime.now(tz.UTC))) return;
    final exact =
        !Platform.isAndroid ||
        (await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.canScheduleExactNotifications() ??
            false);
    await _plugin.zonedSchedule(
      id: _id,
      title: 'Repos terminé',
      body: 'À toi : la série suivante t’attend.',
      scheduledDate: endsAt,
      notificationDetails: _details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  });

  @override
  Future<void> cancel() => _guard('annulée', () async {
    // Jamais programmée sur ce lancement : rien à annuler, et surtout pas
    // de demande de permission pour un repos qu'on vient de passer.
    if (_ready == null) return;
    await _plugin.cancel(id: _id);
  });

  Future<void> _guard(String verbe, Future<void> Function() action) async {
    try {
      await action();
    } on MissingPluginException catch (error) {
      _logger.warning('Fin de repos non $verbe : greffon absent', error: error);
    } on PlatformException catch (error) {
      _logger.warning('Fin de repos non $verbe', error: error);
    }
  }
}

final restAlarmProvider = Provider<RestAlarm>((ref) => LocalRestAlarm());
