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
///  - à la déconnexion : oubli côté serveur PUIS côté appareil ;
///  - à l'expiration de la session ou à la suppression du compte : oubli
///    côté appareil seul, le serveur n'étant plus joignable en son nom.
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

  /// Numéro de la session d'enregistrement. Chaque remise à neuf
  /// l'incrémente : un démarrage parti AVANT (sa requête encore en vol) ne
  /// s'achève plus sur la session d'APRÈS — ni jeton retenu, ni abonnement
  /// au rafraîchissement ressuscité.
  int _generation = 0;

  /// L'oubli en cours (désenregistrement, effacement du jeton chez FCM). Le
  /// démarrage suivant l'ATTEND : sans cela, le compte suivant pouvait
  /// obtenir le jeton même qu'on était en train d'effacer, et l'enregistrer
  /// mort.
  Future<void> _forgetting = Future<void>.value();

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
    unawaited(_start(options, _generation));
  }

  Future<void> _start(FirebasePushOptions options, int generation) async {
    try {
      await _forgetting;
      if (generation != _generation) return;
      final token = await _messenger.obtainToken(options);
      if (generation != _generation) return;
      if (token == null) {
        _logger.info('Notifications refusées : choix respecté, rien envoyé');
        return;
      }
      await _register(token, generation);
      if (generation != _generation) return;
      _refreshSubscription = _messenger.onTokenRefresh.listen(
        (refreshed) => unawaited(_register(refreshed, generation)),
      );
    } on Exception catch (error) {
      _logger.warning('Enregistrement push impossible', error: error);
    }
  }

  Future<void> _register(String token, int generation) async {
    try {
      await _repository.register(token: token, platform: _platform);
      // La session a pu s'achever pendant l'aller-retour : ce jeton n'est
      // plus celui de personne ici, l'oubli s'en est déjà chargé.
      if (generation == _generation) _token = token;
    } on Exception catch (error) {
      // Hors ligne ou serveur indisponible : le prochain démarrage (ou le
      // prochain rafraîchissement de jeton) retentera.
      _logger.warning('Jeton push non enregistré', error: error);
    }
  }

  /// À la déconnexion — avant l'invalidation de la session, l'appel au
  /// serveur étant authentifié. N'échoue jamais l'appelant.
  Future<void> forgetDevice() => _forget(_forgetDevice);

  Future<void> _forgetDevice() async {
    final token = _token;
    _token = null;
    await _reset();

    if (token != null) {
      try {
        await _repository.unregister(token);
      } on Exception catch (error) {
        _logger.warning('Jeton push non désenregistré', error: error);
      }
    }
    // Que le serveur ait répondu ou non, et même si ce lancement n'avait
    // rien enregistré : c'est l'effacement chez FCM qui coupe l'arrivée.
    await _deleteDeviceToken();
  }

  /// L'appareil oublie SANS rien demander au serveur, dans deux cas.
  ///
  /// Après une SUPPRESSION de compte : le compte n'existe plus, ses jetons
  /// d'appareil sont partis avec lui, il n'y a rien à désenregistrer.
  ///
  /// Après une EXPIRATION de session (401 au renouvellement : trente jours
  /// d'inactivité, session révoquée depuis un autre appareil, réutilisation
  /// détectée) : il n'y a plus de session pour parler au serveur. Le jeton
  /// restait pourtant attribué au compte parti : ses notifications (demandes
  /// d'ami, invitations à un défi, avec leur texte) continuaient de
  /// s'afficher sur ce téléphone, y compris pour la personne suivante. Effacer
  /// le jeton chez FCM le rend inutilisable, quoi qu'en garde le serveur.
  ///
  /// Dans les deux cas, tout ce qui restait à faire était LOCAL : la
  /// personne suivante tombait sur un `_started` resté vrai,
  /// `ensureStarted()` ressortait aussitôt, et elle ne recevait AUCUNE
  /// notification jusqu'au redémarrage de l'application.
  Future<void> forgetLocally() => _forget(_forgetLocally);

  Future<void> _forgetLocally() async {
    _token = null;
    await _reset();
    await _deleteDeviceToken();
  }

  /// Efface le jeton de l'APPAREIL chez FCM, qu'on le connaisse ou non.
  ///
  /// Ce processus peut n'avoir rien enregistré — au démarrage à froid après
  /// trente jours, la session expire pendant l'écran de démarrage, avant
  /// que l'accueil n'ait rien lancé — alors que le serveur tient le jeton
  /// d'un lancement plus ancien, au nom du compte parti. Un jeton d'avant le
  /// rattachement aux sessions n'expire avec aucune : sans cet effacement,
  /// ses notifications continuaient d'arriver. Le prix est mince : FCM en
  /// réémet un neuf au prochain démarrage, enregistré au nom du suivant.
  Future<void> _deleteDeviceToken() async {
    final options = _environment.push;
    if (options == null) return;
    try {
      await _messenger.deleteToken(options);
    } on Exception catch (error) {
      _logger.warning('Jeton push local non effacé', error: error);
    }
  }

  /// Retient l'oubli en cours, pour que le démarrage suivant l'attende.
  Future<void> _forget(Future<void> Function() forget) {
    final forgetting = forget();
    _forgetting = forgetting.catchError(
      (Object error) => _logger.warning('Oubli push interrompu', error: error),
    );
    return forgetting;
  }

  /// Remet l'enregistrement À NEUF.
  ///
  /// L'objet SURVIT à la bascule de compte (`pushRegistrationProvider` n'est
  /// pas auto-disposé) : sans cette remise à zéro, `_started` reste vrai pour
  /// le compte suivant. L'abonnement au rafraîchissement part avec, sinon un
  /// jeton renouvelé par FCM s'enregistrerait sous la session d'après.
  ///
  /// L'état change AVANT la première attente : un `ensureStarted()` appelé
  /// pendant l'annulation de l'abonnement repart bien de zéro.
  Future<void> _reset() async {
    _generation++;
    _started = false;
    final subscription = _refreshSubscription;
    _refreshSubscription = null;
    await subscription?.cancel();
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
