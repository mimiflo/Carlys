import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/dio_client.dart';
import '../../../../core/database/local_account_purge.dart';
import '../../../../core/database/local_account_switch.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../notifications/presentation/controllers/push_registration.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';

/// État global de session.
sealed class AuthState {
  const AuthState();
}

/// Démarrage : la présence d'une session locale n'est pas encore connue.
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({this.user});

  /// Renseigné après le chargement du profil ; null juste après restauration.
  final AuthUser? user;
}

/// Source de vérité de l'état de session, consommée par le routeur.
class AuthController extends Notifier<AuthState> {
  static const _logger = AppLogger('AuthController');

  @override
  AuthState build() {
    // La session expirée côté serveur (refresh impossible) déconnecte l'UI.
    ref.watch(tokenRefresherProvider).onSessionExpired = _onSessionExpired;
    return const AuthUnknown();
  }

  /// Restauration au démarrage : session locale présente → authentifié,
  /// le profil est ensuite rafraîchi en arrière-plan.
  Future<void> restore() async {
    final repository = ref.read(authRepositoryProvider);
    if (!await repository.hasStoredSession()) {
      state = const AuthUnauthenticated();
      return;
    }
    // La session restaurée est presque toujours celle du propriétaire déjà
    // retenu : rien à purger. La seule exception est un démarrage juste
    // après une connexion interrompue avant que l'appareil n'ait changé de
    // mains ; ce démarrage-là tranche alors, comme la connexion l'aurait
    // fait. Un échec ne peut pas remonter (l'écran de démarrage appelle
    // sans attendre) : on refuse d'entrer plutôt que d'ouvrir l'application
    // sur des données qui ne sont peut-être pas les siennes.
    try {
      await ref.read(localAccountSwitchProvider).claimDevice();
    } catch (error) {
      _logger.error('Entrée dans le compte refusée', error: error);
      state = const AuthUnauthenticated();
      return;
    }
    state = const AuthAuthenticated();
    try {
      state = AuthAuthenticated(user: await repository.me());
    } on Exception catch (error) {
      // Hors ligne ou serveur indisponible : la session locale reste valable.
      // Une session réellement invalide déclenche onSessionExpired.
      _logger.warning('Profil non rafraîchi au démarrage', error: error);
    }
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    await _enterAccount();
    state = AuthAuthenticated(user: user);
    return user;
  }

  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .register(email: email, password: password, displayName: displayName);
    await _enterAccount();
    state = AuthAuthenticated(user: user);
    return user;
  }

  Future<void> logout() async {
    // Le jeton push est oublié AVANT la session : l'appel au serveur est
    // encore authentifié. Un échec n'empêche jamais la déconnexion.
    await ref.read(pushRegistrationProvider).forgetDevice();
    await ref.read(authRepositoryProvider).logout();
    await _leaveAccount();
  }

  /// Recharge le profil (après une modification par exemple).
  Future<void> refreshProfile() async {
    if (state is! AuthAuthenticated) return;
    state = AuthAuthenticated(
      user: await ref.read(authRepositoryProvider).me(),
    );
  }

  /// Session expirée côté serveur (401 au renouvellement) : l'interface
  /// bascule, et RIEN n'est effacé.
  ///
  /// Ce n'est pas un changement de compte : c'est le même utilisateur, sur
  /// son compte, revenu après l'expiration du jeton de renouvellement (trente
  /// jours). Purger ici détruisait ses séances, ses séries et ses opérations
  /// en file non synchronisées — les siennes. La purge est différée à la
  /// connexion d'un compte différent (`LocalAccountSwitch`) : s'il se
  /// reconnecte, il retrouve tout et la file repart ; si quelqu'un d'autre se
  /// connecte, tout part avant qu'il ne voie quoi que ce soit.
  void _onSessionExpired() {
    if (state is AuthUnauthenticated) {
      return;
    }
    state = const AuthUnauthenticated();
  }

  /// Entrée dans un compte : l'appareil est réclamé avant que l'interface ne
  /// bascule, donc avant que le moindre drainage ou rapatriement ne démarre.
  /// L'échec remonte volontairement : la connexion échoue à l'écran plutôt
  /// que d'ouvrir l'application sur les données d'un autre compte.
  Future<void> _enterAccount() =>
      ref.read(localAccountSwitchProvider).claimDevice();

  /// Frontière de compte : l'appareil ne garde rien du compte qui part,
  /// PUIS l'interface bascule — le compte suivant ne peut pas se connecter
  /// sur des données qui ne sont pas les siennes. Une purge qui échoue est
  /// journalisée mais ne retient jamais la déconnexion.
  Future<void> _leaveAccount() async {
    try {
      await ref.read(localAccountPurgeProvider).run();
    } catch (error) {
      // Attrape TOUT, pas seulement `Exception` : une base Drift déjà fermée
      // et un conteneur Riverpod déjà disposé signalent par une `StateError`,
      // qui est une `Error` — le moteur de synchronisation documente et teste
      // déjà ce cas. Deux purges concurrentes suffisent à le produire (une
      // suppression de compte pendant une déconnexion, une double touche sur
      // « Se déconnecter ») : la seconde trouve la base fermée par la
      // première. Non interceptée, l'erreur s'échapperait et l'état ne
      // basculerait JAMAIS : l'utilisateur resterait « connecté » sur un
      // compte qui n'existe plus. Une purge est un nettoyage, son échec ne
      // vaut jamais de retenir la déconnexion.
      _logger.error('Purge locale du compte impossible', error: error);
    }
    state = const AuthUnauthenticated();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
