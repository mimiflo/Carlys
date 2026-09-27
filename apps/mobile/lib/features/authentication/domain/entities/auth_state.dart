import 'auth_user.dart';

/// ÉTAT GLOBAL DE SESSION, lu par le routeur avant toute chose.
///
/// Un état, pas un contrôleur : il vit donc avec les entités du domaine, et
/// `auth_controller.dart` ne porte plus que la conduite de la session.
sealed class AuthState {
  const AuthState();

  /// Vrai si un profil revenu du serveur appartient À CETTE session.
  ///
  /// La réponse revient LONGTEMPS après le départ, et l'appareil a pu
  /// changer de mains entre les deux. Regarder seulement « y a-t-il une
  /// session ouverte ? » ne suffit pas : une réponse partie pour le compte
  /// A, revenue après que A s'est déconnecté et que B s'est connecté,
  /// réinstallait A par-dessus B — le profil affichait le nom et l'adresse
  /// du compte précédent jusqu'au prochain `me()`. On compare donc
  /// l'IDENTITÉ, ce qui couvre du même geste la session fermée entre-temps
  /// (déconnexion, expiration) : on ne rallume rien. Un profil encore
  /// inconnu (restauration hors ligne) ne peut être que celui de la session
  /// restaurée : il l'accepte.
  bool accepts(AuthUser fetched) => switch (this) {
    AuthAuthenticated(:final user) => user == null || user.id == fetched.id,
    AuthUnknown() || AuthUnauthenticated() => false,
  };
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
