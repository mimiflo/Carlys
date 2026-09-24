/// Messager push de test : en mémoire, pilotable.
///
/// LA SEULE doublure de [PushMessenger] du dépôt. L'enregistrement du jeton,
/// le bandeau des notifications reçues application ouverte et l'ouverture de
/// l'écran qu'annonce une notification touchée se testent tous contre elle :
/// aucun test ne touche le plugin Firebase.
library;

import 'dart:async';

import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/features/notifications/domain/entities/push_destination.dart';
import 'package:carlys_mobile/features/notifications/domain/services/push_messenger.dart';

class FakePushMessenger implements PushMessenger {
  FakePushMessenger({this.token = 'jeton-1', this.launchDestination});

  /// Jeton rendu par [obtainToken] — null simule une permission refusée.
  String? token;

  /// La notification dont le toucher a « lancé » l'application.
  PushDestination? launchDestination;

  int obtainCalls = 0;
  int deleteCalls = 0;
  int launchCalls = 0;
  final StreamController<String> refreshes = StreamController.broadcast();
  final StreamController<PushNotice> notices = StreamController.broadcast();
  final StreamController<PushDestination> opened = StreamController.broadcast();

  @override
  Future<String?> obtainToken(FirebasePushOptions options) async {
    obtainCalls += 1;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;

  @override
  Stream<PushNotice> get onForegroundMessage => notices.stream;

  @override
  Stream<PushDestination> get onNotificationOpened => opened.stream;

  /// Comme le SDK : la destination de lancement ne se rend qu'UNE fois.
  @override
  Future<PushDestination?> takeLaunchDestination(
    FirebasePushOptions options,
  ) async {
    launchCalls += 1;
    final destination = launchDestination;
    launchDestination = null;
    return destination;
  }

  @override
  Future<void> deleteToken() async {
    deleteCalls += 1;
  }

  /// À poser en `addTearDown` : aucun flux ne reste ouvert après le test.
  Future<void> close() async {
    await refreshes.close();
    await notices.close();
    await opened.close();
  }
}
