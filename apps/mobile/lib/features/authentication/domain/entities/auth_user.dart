/// Utilisateur authentifié.
///
/// Immuable, écrit à la main pour l'instant : la migration vers Freezed se
/// fera quand la génération de code entrera dans la boucle CI.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.locale,
    required this.timezone,
  });

  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;
  final String locale;
  final String timezone;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName &&
      other.emailVerified == emailVerified &&
      other.locale == locale &&
      other.timezone == timezone;

  @override
  int get hashCode =>
      Object.hash(id, email, displayName, emailVerified, locale, timezone);
}
