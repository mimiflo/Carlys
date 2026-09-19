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
/// Sans configuration Firebase (tests, CI) c'est un no-op assumé :
/// l'application vit exactement pareil, personne n'est joignable, rien ne
/// casse. Aucun échec ici n'atteint jamais un flux métier.
class PushRegistration {
  PushRegistration({
    required this._environment,
    required this._messenger,
    required this._repository,
  });

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
    if (options == null) {
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
    await _reset();

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

  /// Après une SUPPRESSION de compte : l'appareil oublie SANS rien demander
  /// au serveur.
  ///
  /// Le compte n'existe plus, ses jetons d'appareil sont partis avec lui : il
  /// n'y a rien à désenregistrer. Mais tout ce qui restait à faire était
  /// LOCAL, et ne se faisait pas — ce chemin n'appelait rien du tout. La
  /// personne suivante qui se connectait sur cet appareil tombait sur un
  /// `_started` resté vrai, `ensureStarted()` ressortait aussitôt, et elle ne
  /// recevait AUCUNE notification jusqu'au redémarrage de l'application.
  Future<void> forgetLocally() async {
    await _reset();

    if (_token == null) {
      return;
    }
    _token = null;
    try {
      // Le jeton de l'appareil change : celui d'avant a été révoqué avec le
      // compte, le garder ferait ré-enregistrer un jeton mort.
      await _messenger.deleteToken();
    } on Exception catch (error) {
      _logger.warning('Jeton push local non effacé', error: error);
    }
  }

  /// Remet l'enregistrement À NEUF.
  ///
  /// L'objet SURVIT à la bascule de compte (`pushRegistrationProvider` n'est
  /// pas auto-disposé) : sans cette remise à zéro, `_started` reste vrai pour
  /// le compte suivant. L'abonnement au rafraîchissement part avec, sinon un
  /// jeton renouvelé par FCM s'enregistrerait sous la session d'après.
  Future<void> _reset() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    _started = false;
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
