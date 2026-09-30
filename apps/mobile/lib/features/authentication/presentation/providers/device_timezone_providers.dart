import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Lecture du fuseau IANA de l'appareil (« America/Montreal »), injectable :
/// les tests ne doivent jamais dépendre du fuseau de la machine de CI, et
/// aucun greffon de plateforme ne répond dans un test de widget.
typedef DeviceTimezoneReader = Future<String> Function();

final deviceTimezoneReaderProvider = Provider<DeviceTimezoneReader>((ref) {
  return () async => (await FlutterTimezone.getLocalTimezone()).identifier;
});

/// Aligne le fuseau connu du SERVEUR sur celui de l'appareil.
///
/// C'est le serveur qui découpe les jours : la série de constance qu'un ami
/// voit est calculée dans le fuseau du profil. Tant que personne ne l'envoie,
/// tout le monde reste au défaut du serveur (Europe/Paris), et une séance du
/// dimanche 19 h à Montréal devient une séance du lundi 1 h à Paris — la
/// série se décale d'un jour entier pour ceux qui la regardent.
///
/// La référence est la valeur RENDUE PAR LE SERVEUR (`AuthUser.timezone`), et
/// non une trace gardée sur l'appareil : elle est déjà là à chaque
/// restauration, elle est juste par construction, et elle appartient au
/// compte connecté — un second compte sur le même téléphone ne peut donc pas
/// hériter du « déjà envoyé » du premier.
///
/// Un échec ne remonte JAMAIS à l'appelant : ni un fuseau illisible ni un
/// réseau absent ne doivent empêcher une connexion. Le prochain démarrage
/// retentera, puisque le serveur n'aura toujours pas la bonne valeur — SAUF
/// si le serveur a refusé la valeur elle-même : ce refus-là ne guérit pas en
/// réessayant, et la reproposer à chaque lancement ne ferait que répéter le
/// même échec en silence.
class DeviceTimezoneSync {
  // Plus `const` : l'objet retient les valeurs refusées le temps de la
  // session. C'est ce qui casse la boucle, donc c'est un état assumé.
  DeviceTimezoneSync({
    required this.repository,
    required this.readDeviceTimezone,
  });

  static const _logger = AppLogger('DeviceTimezoneSync');

  final AuthRepository repository;

  /// Injectée plutôt qu'appelée directement : voir [DeviceTimezoneReader].
  final DeviceTimezoneReader readDeviceTimezone;

  /// Les valeurs que le serveur a REFUSÉES, pour ne pas les lui reproposer.
  ///
  /// Le rejeu au démarrage suivant est le bon réflexe face à une panne
  /// passagère — réseau coupé, serveur indisponible. Il est absurde face à un
  /// refus définitif : depuis que le fuseau est validé côté serveur, un
  /// identifiant que l'appareil rend et que le serveur n'accepte pas (certains
  /// Android rendent un décalage brut plutôt qu'un nom IANA) était renvoyé à
  /// CHAQUE lancement, refusé à chaque fois, sans qu'aucun écran ne le dise.
  /// On le retient donc pour la durée de la session.
  final Set<String> _refuses = <String>{};

  /// Rend l'utilisateur mis à jour quand un envoi a eu lieu, `null` quand il
  /// n'y avait rien à envoyer ou que l'envoi a échoué.
  Future<AuthUser?> reconcile(AuthUser user) async {
    final String device;
    try {
      device = await readDeviceTimezone();
    } on Object catch (error) {
      // Greffon absent (bureau, test) ou plateforme muette : on se tait.
      _logger.warning('Fuseau de l’appareil illisible', error: error);
      return null;
    }

    if (device.isEmpty || device == user.timezone) return null;
    if (_refuses.contains(device)) return null;

    try {
      final updated = await repository.updateTimezone(device);
      _logger.info('Fuseau déclaré au serveur : $device');
      return updated;
    } on Object catch (error) {
      // `on Object`, et non `on AppException` : le dépôt ne convertit que les
      // `DioException`, et une enveloppe de réponse inattendue lève une
      // `FormatException` qui n'est pas une `AppException`. Comme l'appel est
      // lancé sans être attendu, une erreur non filtrée ici atterrirait dans
      // le `runZonedGuarded` de `bootstrap()` — alors que la promesse tenue
      // plus haut est qu'un échec ne remonte JAMAIS. Le prochain démarrage
      // retentera, le serveur n'ayant toujours pas la bonne valeur.
      // Un refus de VALIDATION ne guérit pas en réessayant : la même valeur
      // donnerait le même refus, à chaque lancement, pour toujours. Les
      // autres échecs (réseau, serveur) restent rejouables.
      if (error is ValidationException) {
        _refuses.add(device);
        _logger.warning(
          'Fuseau « $device » refusé par le serveur : plus renvoyé de cette '
          'session',
          error: error,
        );
        return null;
      }
      _logger.warning('Fuseau non déclaré', error: error);
      return null;
    }
  }
}

final deviceTimezoneSyncProvider = Provider<DeviceTimezoneSync>((ref) {
  return DeviceTimezoneSync(
    repository: ref.watch(authRepositoryProvider),
    readDeviceTimezone: ref.watch(deviceTimezoneReaderProvider),
  );
});
