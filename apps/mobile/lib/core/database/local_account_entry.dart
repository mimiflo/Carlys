import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../errors/app_exception.dart';
import '../logging/app_logger.dart';
import 'local_account_switch.dart';

/// L'ENTRÉE dans un compte dont le serveur vient d'ouvrir la session :
/// connexion, inscription, connexion Apple ou Google — les trois portes
/// d'`AuthController`, et elles seules.
///
/// L'appareil est réclamé (`LocalAccountSwitch.claimDevice`) avant que
/// l'interface ne bascule, donc avant que le moindre drainage ou
/// rapatriement ne démarre. Si la réclamation échoue, on n'entre pas : ce
/// serait ouvrir l'application de ce compte sur les données d'un autre.
///
/// **Et la session tout juste ouverte est ABANDONNÉE** — révoquée côté
/// serveur au mieux, ses jetons effacés du trousseau. Les laisser en place,
/// comme c'était le cas, avait deux effets :
///
///  1. une session à moitié ouverte : l'écran reste celui de la connexion,
///     mais chaque requête partie de là porte le jeton du compte refusé
///     (l'intercepteur lit le trousseau), et le serveur liste un appareil
///     connecté que rien, ici, ne permet de fermer ;
///  2. plus grave, une entrée DIFFÉRÉE : au lancement suivant,
///     `AuthController.restore()` trouve une session enregistrée et rejoue
///     `claimDevice()`. Qu'il réussisse cette fois, et l'application
///     s'ouvre en silence sur le compte à qui l'on avait dit « échec » —
///     après avoir PURGÉ, pour lui faire place, le travail hors ligne non
///     synchronisé de celui à qui l'appareil a été rendu entre-temps.
///
/// Rien n'est purgé EN PLUS ici : le propriétaire précédent garde ce que la
/// réclamation n'a pas eu le temps d'effacer. Son marqueur n'est retiré
/// qu'en dernier par la purge (`LocalAccountPurge`) : tant qu'il reste, sa
/// prochaine entrée le reconnaît ; s'il est parti, c'est que ses données
/// l'étaient déjà.
///
/// `restore()`, lui, n'abandonne pas : la session qu'il trouve est celle
/// que l'appareil avait déjà, personne ne s'est vu répondre « échec », et
/// garder les jetons permet au lancement suivant de réessayer sans coûter
/// une reconnexion pour une panne locale passagère. Depuis que les trois
/// portes abandonnent, une session présente au démarrage est une session
/// entrée — ou une connexion interrompue par l'arrêt de l'application, le
/// cas que `restore()` documente et tranche.
class LocalAccountEntry {
  LocalAccountEntry(this._ref);

  static const _logger = AppLogger('LocalAccountEntry');

  final Ref _ref;

  /// Réclame l'appareil, ou abandonne la session et lève
  /// [AccountClaimException] (la cause d'origine y est portée).
  Future<void> enter() async {
    try {
      await _ref.read(localAccountSwitchProvider).claimDevice();
    } catch (error, trace) {
      // `catch` NU : une base Drift fermée ou un conteneur disposé signalent
      // par une `StateError`, qui est une `Error`.
      await _abandonSession();
      throw AccountClaimException(
        'Appareil non réclamé pour le compte entrant',
        cause: error,
        stackTrace: trace,
      );
    }
  }

  /// Ne jette jamais : il sert après un échec, qu'il ne doit pas masquer.
  /// `AuthRepository.logout` et non `AuthController.logout` : ce dernier
  /// PURGE, et il n'y a rien à purger d'un compte où l'on n'est pas entré.
  Future<void> _abandonSession() async {
    try {
      await _ref.read(authRepositoryProvider).logout();
    } catch (error) {
      _logger.error('Session refusée non abandonnée', error: error);
    }
  }
}

final localAccountEntryProvider = Provider<LocalAccountEntry>(
  LocalAccountEntry.new,
);
