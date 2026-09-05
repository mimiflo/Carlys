import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/dio_client.dart';
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
    state = AuthAuthenticated(user: user);
    return user;
  }

  Future<void> logout() async {
    // Le jeton push est oublié AVANT la session : l'appel au serveur est
    // encore authentifié. Un échec n'empêche jamais la déconnexion.
    await ref.read(pushRegistrationProvider).forgetDevice();
    await ref.read(authRepositoryProvider).logout();
    state = const AuthUnauthenticated();
  }

  /// Recharge le profil (après une modification par exemple).
  Future<void> refreshProfile() async {
    if (state is! AuthAuthenticated) return;
    state = AuthAuthenticated(
      user: await ref.read(authRepositoryProvider).me(),
    );
  }

  void _onSessionExpired() {
    if (state is! AuthUnauthenticated) {
      state = const AuthUnauthenticated();
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
