import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/environment/app_environment.dart';
import '../../domain/entities/push_destination.dart';
import '../../domain/services/push_messenger.dart';

/// Seul fichier du dépôt qui connaisse les plugins Firebase.
///
/// L'initialisation est PROGRAMMATIQUE (options injectées au lancement) :
/// aucun `google-services.json` n'est requis dans `android/`, qui n'est
/// d'ailleurs pas versionné — le greffon Gradle non plus.
class FirebasePushMessenger implements PushMessenger {
  @override
  Future<String?> obtainToken(FirebasePushOptions options) async {
    await _ensureInitialized(options);
    final messaging = FirebaseMessaging.instance;
    // Sur Android 13+ comme sur iOS, la permission se DEMANDE ; la refuser
    // est un choix respecté — on rend null, jamais une erreur.
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    return messaging.getToken();
  }

  static Future<void> _ensureInitialized(FirebasePushOptions options) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: options.apiKey,
          appId: options.appId,
          messagingSenderId: options.messagingSenderId,
          projectId: options.projectId,
        ),
      );
    }
  }

  static PushDestination? _destinationOf(RemoteMessage message) =>
      PushDestination.fromData(message.data);

  @override
  Stream<PushDestination> get onNotificationOpened => FirebaseMessaging
      .onMessageOpenedApp
      .map(_destinationOf)
      .where((destination) => destination != null)
      .cast<PushDestination>();

  @override
  Future<PushDestination?> takeLaunchDestination(
    FirebasePushOptions options,
  ) async {
    await _ensureInitialized(options);
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : _destinationOf(message);
  }

  @override
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  /// Au premier plan, le système n'affiche RIEN de lui-même : sans cette
  /// écoute, une notification reçue pendant qu'on utilise l'application
  /// n'existerait pas. On ne garde que les messages qui portent un titre et
  /// un corps — les messages de données pures n'ont rien à montrer.
  @override
  Stream<PushNotice> get onForegroundMessage => FirebaseMessaging.onMessage
      .map((message) {
        final notification = message.notification;
        if (notification == null) return null;
        return PushNotice(
          title: notification.title ?? 'Carlys',
          body: notification.body ?? '',
          destination: _destinationOf(message),
        );
      })
      .where((notice) => notice != null)
      .cast<PushNotice>();

  @override
  Future<void> deleteToken() => FirebaseMessaging.instance.deleteToken();
}

final pushMessengerProvider = Provider<PushMessenger>(
  (ref) => FirebasePushMessenger(),
);
