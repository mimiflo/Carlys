import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/app_logger.dart';
import '../../features/workout_session/data/services/local_rest_alarm.dart';
import '../../features/workout_session/domain/services/rest_alarm.dart';

/// Les autorisations demandées au PREMIER lancement (décision du
/// propriétaire, 10 octobre 2026), une fois par installation :
///
///  - les notifications : la fin de repos, écran éteint ;
///  - l'appareil photo : le scan du code ami et la photo d'un repas.
///
/// Une réponse, quelle qu'elle soit, est définitive pour ce moment : on ne
/// redemande pas au lancement suivant. Chaque fonction la redemande ensuite
/// à son tour si elle manque (le scan, la photo, le premier repos).
///
/// Sur iOS, Flutter 3.44 passe par Swift Package Manager : le greffon y
/// active l'autorisation de l'appareil photo d'après le motif déjà posé dans
/// `Info.plist` (`NSCameraUsageDescription`, `android_branding.sh`). Sous
/// CocoaPods, sans ce réglage, la demande répondrait « refusé » sans boîte,
/// et le scan la redemanderait à l'ouverture : rien ne casse.
class FirstLaunchPermissions {
  FirstLaunchPermissions(
    this._alarm, {
    Future<void> Function()? requestCamera,
    bool? askCamera,
  }) : _requestCamera = requestCamera ?? _systemCamera,
       _askCamera = askCamera ?? (Platform.isAndroid || Platform.isIOS);

  static const _logger = AppLogger('FirstLaunchPermissions');

  /// Posée après la demande : l'installation a déjà répondu.
  static const String askedKey = 'permissions.premier_lancement';

  final RestAlarm _alarm;
  final Future<void> Function() _requestCamera;
  final bool _askCamera;

  static Future<void> _systemCamera() => Permission.camera.request();

  /// Au-delà, une boîte n'a jamais rendu sa réponse (activité recréée
  /// pendant la demande) : on passe à la suivante.
  static const Duration _answerTimeout = Duration(minutes: 1);

  /// Demande, une seule fois. Une panne (greffon absent, plateforme sans
  /// caméra, réponse perdue) se journalise et ne bloque jamais l'appli.
  Future<void> requestOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(askedKey) ?? false) return;
      // Posée AVANT les boîtes : une appli tuée pendant la demande ne la
      // reposera pas en boucle à chaque lancement.
      await prefs.setBool(askedKey, true);
      await _ask('Notifications', () => _alarm.prepare());
      if (_askCamera) await _ask('Appareil photo', _requestCamera);
    } on Exception catch (error) {
      _logger.warning('Autorisations du premier lancement', error: error);
    }
  }

  Future<void> _ask(String what, Future<void> Function() request) async {
    try {
      await request().timeout(_answerTimeout);
    } on Exception catch (error) {
      _logger.warning('$what non demandé', error: error);
    }
  }
}

final firstLaunchPermissionsProvider = Provider<FirstLaunchPermissions>(
  (ref) => FirstLaunchPermissions(ref.watch(restAlarmProvider)),
);
