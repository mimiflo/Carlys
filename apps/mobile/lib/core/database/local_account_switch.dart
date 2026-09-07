import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../logging/app_logger.dart';
import 'local_account_owner.dart';
import 'local_account_purge.dart';

/// Frontière de compte à l'ENTRÉE : l'état local n'est purgé qu'au moment
/// où un compte DIFFÉRENT prend l'appareil.
///
/// L'expiration de session n'est pas un changement de compte. Elle survient
/// sur un 401 du renouvellement, c'est-à-dire typiquement après trente jours
/// sans ouvrir l'application (`REFRESH_TOKEN_TTL_DAYS`). Purger à ce
/// moment-là détruisait les séances, les séries et les opérations en file du
/// MÊME utilisateur, sur SON compte — contre la garantie « aucune série
/// saisie n'est jamais perdue » que la documentation continue d'afficher.
/// La purge est donc différée jusqu'ici.
///
/// Attendre ne fait courir aucun risque : chaque opération de la file porte
/// le compte sous lequel elle a été écrite et le moteur refuse déjà de
/// drainer celle d'un autre ; et cette routine s'exécute AVANT que l'état
/// ne passe authentifié, donc avant que le moindre déclencheur de
/// synchronisation ou de rapatriement ne démarre.
///
/// La déconnexion volontaire, elle, purge toujours sur-le-champ : on quitte
/// un compte en le disant, et rien ne doit rester lisible sur l'appareil.
abstract interface class LocalAccountSwitch {
  /// À appeler à chaque entrée dans un compte (connexion, inscription,
  /// restauration au démarrage), avant de basculer l'interface : purge si
  /// l'appareil portait les données d'un autre compte, puis retient le
  /// nouveau propriétaire.
  ///
  /// Jette si la purge échoue : entrer quand même, ce serait ouvrir
  /// l'application du nouveau compte sur les données de l'ancien.
  Future<void> claimDevice();
}

class StoredLocalAccountSwitch implements LocalAccountSwitch {
  StoredLocalAccountSwitch(this._ref);

  static const _logger = AppLogger('LocalAccountSwitch');

  final Ref _ref;

  @override
  Future<void> claimDevice() async {
    final arriving = await _ref.read(authRepositoryProvider).currentAccountId();
    if (arriving == null) {
      // Session absente ou illisible : on ne sait pas qui arrive. Ne rien
      // purger sur un doute — détruire des données sur une session qu'on ne
      // sait même pas lire serait bien pire que d'attendre l'entrée
      // suivante, qui tranchera.
      _logger.warning('Compte entrant inconnu : rien n’est purgé');
      return;
    }
    final owner = _ref.read(localAccountOwnerProvider);
    final present = await owner.read();
    if (present != null && present != arriving) {
      _logger.info('Compte différent sur cet appareil : purge de l’état local');
      await _ref.read(localAccountPurgeProvider).run();
    }
    // Après la purge : elle efface justement ce marqueur.
    await owner.write(arriving);
  }
}

final localAccountSwitchProvider = Provider<LocalAccountSwitch>(
  StoredLocalAccountSwitch.new,
);
