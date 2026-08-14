import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/environment/app_environment.dart';
import '../../../../core/logging/app_logger.dart';
import '../../data/repositories/device_token_repository_impl.dart';
import '../../data/services/firebase_push_messenger.dart';
import '../../domain/repositories/device_token_repository.dart';
import '../../domain/services/push_messenger.dart';

/// Cycle de vie de l'enregistrement push, sur le modèle de `SyncLifecycle` :
///  - à l'entrée dans l'application authentifiée : permission puis jeton,
///    envoyé au serveur ;
///  - à chaque rafraîchissement de jeton par FCM : ré-enregistrement ;
///  - à la déconnexion : oubli côté serveur PUIS côté appareil.
///
/// Sans configuration Firebase (tests, CI, démo) c'est un no-op assumé :
/// l'application vit exactement pareil, personne n'est joignable, rien ne
/// casse. Aucun échec ici n'atteint jamais un flux métier.
class PushRegistration {
  PushRegistration({
    required AppEnvironment environment,
    required PushMessenger messenger,
    required DeviceTokenRepository repository,
  })  : _environment = environment,
        _messenger = messenger,
        _repository = repository;

  static const _logger = AppLogger('PushRegistration');

  final AppEnvironment _environment;
  final PushMessenger _messenger;
  final DeviceTokenRepository _repository;

  StreamSubscription<String>? _refreshSubscription;
  bool _started = false;
  String? _token;

  /// Jeton actuellement enregistré côté serveur (null tant que rien n'a
  /// abouti — configuration absente, permission refusée, serveur injoignable).
  String? get registeredToken => _token;

  void ensureStarted() {
    if (_started) {
      return;
    }
    _started = true;

    final options = _environment.push;
    if (_environment.isDemo || options == null) {
      _logger.info(
        'Notifications push inactives : pas de configuration Firebase',
      );
      return;
    }
    unawaited(_start(options));
  }

  Future<void> _start(FirebasePushOptions options) async {
    try {
      final token = await _messenger.obtainToken(options);
      if (token == null) {
        _logger.info('Notifications refusées : choix respecté, rien envoyé');
        return;
      }
      await _register(token);
      _refreshSubscription = _messenger.onTokenRefresh.listen(
        (refreshed) => unawaited(_register(refreshed)),
      );
    } on Exception catch (error) {
      _logger.warning('Enregistrement push impossible', error: error);
    }
  }

  Future<void> _register(String token) async {
    try {
      await _repository.register(token: token, platform: _platform);
      _token = token;
    } on Exception catch (error) {
      // Hors ligne ou serveur indisponible : le prochain démarrage (ou le
      // prochain rafraîchissement de jeton) retentera.
      _logger.warning('Jeton push non enregistré', error: error);
    }
  }

  /// À la déconnexion — avant l'invalidation de la session, l'appel au
  /// serveur étant authentifié. N'échoue jamais l'appelant.
  Future<void> forgetDevice() async {
    final token = _token;
    if (token == null) {
      return;
    }
    _token = null;
    try {
      await _repository.unregister(token);
      await _messenger.deleteToken();
    } on Exception catch (error) {
      _logger.warning('Jeton push non oublié', error: error);
    }
  }

  DevicePlatform get _platform => defaultTargetPlatform == TargetPlatform.iOS
      ? DevicePlatform.ios
      : DevicePlatform.android;

  void dispose() {
    unawaited(_refreshSubscription?.cancel());
  }
}

final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  final registration = PushRegistration(
    environment: ref.watch(appEnvironmentProvider),
    messenger: ref.watch(pushMessengerProvider),
    repository: ref.watch(deviceTokenRepositoryProvider),
  );
  ref.onDispose(registration.dispose);
  return registration;
});
