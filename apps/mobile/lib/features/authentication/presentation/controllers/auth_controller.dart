import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/dio_client.dart';
import '../../../../core/database/local_account_entry.dart';
import '../../../../core/database/local_account_purge.dart';
import '../../../../core/database/local_account_switch.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../notifications/presentation/controllers/push_registration.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/social_provider.dart';
import 'device_timezone_controller.dart';

// L'état vit dans le domaine ; il se relit par ce fichier, comme avant, pour
// que les dizaines d'écrans qui l'observent n'aient pas à changer d'import.
export '../../domain/entities/auth_state.dart';

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
    // La lecture du trousseau peut ÉCHOUER, pas seulement rendre faux (un
    // keystore Android en vrac après restauration ou montée d'OS). Sans ce
    // filet, l'état restait `AuthUnknown` et le routeur renvoyait
    // indéfiniment sur l'écran de démarrage : application figée, sans un mot
    // — `restore()` n'est appelé qu'une fois. `catch` NU, même raison que
    // `_leaveAccount` ; la connexion est le repli sûr, elle n'efface rien.
    bool stored;
    try {
      stored = await repository.hasStoredSession();
    } catch (error, trace) {
      _logger.error(
        'Session locale illisible : retour à la connexion',
        error: error,
        stackTrace: trace,
      );
      state = const AuthUnauthenticated();
      return;
    }
    if (!stored) {
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
      final user = await repository.me();
      state = AuthAuthenticated(user: user);
      unawaited(_declareDeviceTimezone(user));
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
    unawaited(_declareDeviceTimezone(user));
    return user;
  }

  /// Connexion Apple ou Google. `null` si la personne a renoncé devant la
  /// feuille du fournisseur — l'état de session ne bouge alors pas d'un pouce.
  Future<AuthUser?> signInWithProvider(SocialProvider provider) async {
    final user = await ref
        .read(authRepositoryProvider)
        .signInWithProvider(provider);
    if (user == null) return null;
    await _enterAccount();
    state = AuthAuthenticated(user: user);
    unawaited(_declareDeviceTimezone(user));
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
    // Un compte tout neuf porte le fuseau PAR DÉFAUT du serveur : c'est le
    // moment où l'écart est certain, et où le corriger coûte le moins.
    unawaited(_declareDeviceTimezone(user));
    return user;
  }

  /// Aligne le fuseau du profil sur celui de l'appareil, si besoin.
  ///
  /// JAMAIS attendu par l'appelant : la lecture passe par un canal de
  /// plateforme, et un canal qui ne répond pas (bureau, banc de test, greffon
  /// absent) retiendrait sinon une restauration ou une connexion pour
  /// toujours. Une session ne se joue pas sur un fuseau horaire.
  Future<void> _declareDeviceTimezone(AuthUser user) async {
    final updated = await ref.read(deviceTimezoneSyncProvider).reconcile(user);
    if (updated == null) return;

    // La réponse revient LONGTEMPS après le départ, et l'appareil a pu
    // changer de mains entre les deux. Regarder seulement « y a-t-il une
    // session ouverte ? » ne suffit pas : une déclaration partie pour le
    // compte A, revenue après que A s'est déconnecté et que B s'est
    // connecté, réinstallait A par-dessus B — le profil affichait le nom et
    // l'adresse du compte précédent jusqu'au prochain `me()`. C'est
    // exactement la frontière de compte que `LocalAccountSwitch` et la purge
    // locale défendent partout ailleurs. On compare donc l'IDENTITÉ, ce qui
    // couvre du même geste la session fermée entre-temps (déconnexion,
    // expiration) : on ne rallume rien.
    final current = state;
    if (current is! AuthAuthenticated || current.user?.id != updated.id) {
      _logger.info('Fuseau reçu hors de la session qui l’a demandé');
      return;
    }
    state = AuthAuthenticated(user: updated);
  }

  Future<void> logout() async {
    // Le jeton push est oublié AVANT la session : l'appel au serveur est
    // encore authentifié. Un échec n'empêche jamais la déconnexion.
    await ref.read(pushRegistrationProvider).forgetDevice();
    await ref.read(authRepositoryProvider).logout();
    await _leaveAccount();
  }

  /// Le compte vient d'être supprimé côté serveur : l'appareil l'oublie.
  ///
  /// Rien n'est demandé au SERVEUR ici — ni déconnexion ni désenregistrement
  /// du jeton push : la suppression a déjà retiré sessions, refresh tokens et
  /// jetons d'appareil. Restent trois gestes LOCAUX : remettre à neuf
  /// l'enregistrement push, effacer les jetons du trousseau, puis purger la
  /// frontière de compte, qui bascule l'interface vers l'écran de connexion.
  ///
  /// NE JETTE JAMAIS : l'écran appelle `submit()` sans l'attendre, donc une
  /// exception d'ici deviendrait une erreur asynchrone non capturée.
  Future<void> forgetDeletedAccount() async {
    // L'enregistrement push SURVIT à la bascule de compte, et ce chemin ne le
    // touchait pas : `ensureStarted()` ressortait aussitôt pour la personne
    // suivante, qui ne recevait plus rien jusqu'au redémarrage.
    await ref.read(pushRegistrationProvider).forgetLocally();
    try {
      await ref.read(authRepositoryProvider).clearLocalSession();
    } catch (error) {
      // Attrape TOUT, comme la purge plus bas : le trousseau descend jusqu'au
      // stockage sécurisé de la plateforme, qui refuse par une
      // `PlatformException` comme par une `Error` (matériel verrouillé,
      // keystore en vrac, canal absent). Laisser filer coûtait cher : la
      // bascule n'avait jamais lieu et l'écran restait tel quel — compte
      // détruit côté serveur, jetons toujours sur l'appareil, pas un mot à
      // l'utilisateur. Ces jetons ne valent d'ailleurs plus rien.
      _logger.error('Jetons du compte supprimé non effacés', error: error);
    }
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

  /// Entrée dans un compte, AVANT que l'interface ne bascule : l'appareil est
  /// réclamé, ou la session tout juste ouverte est abandonnée et l'erreur
  /// remonte (`LocalAccountEntry` dit pourquoi, et pourquoi pas `restore`).
  Future<void> _enterAccount() => ref.read(localAccountEntryProvider).enter();

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
