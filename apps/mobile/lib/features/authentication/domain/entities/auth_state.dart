import 'auth_user.dart';

/// ÉTAT GLOBAL DE SESSION, lu par le routeur avant toute chose.
///
/// Un état, pas un contrôleur : il vit donc avec les entités du domaine, et
/// `auth_controller.dart` ne porte plus que la conduite de la session.
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
