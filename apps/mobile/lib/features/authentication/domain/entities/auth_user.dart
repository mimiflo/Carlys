import '../../../carlys_profile/domain/entities/carlys_profile.dart';

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
    this.carlysProfile,
  });

  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;
  final String locale;
  final String timezone;

  /// Identité Carlys choisie — null tant qu'elle ne l'a pas été.
  final CarlysProfile? carlysProfile;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName &&
      other.emailVerified == emailVerified &&
      other.locale == locale &&
      other.timezone == timezone &&
      other.carlysProfile == carlysProfile;

  @override
  int get hashCode => Object.hash(
        id,
        email,
        displayName,
        emailVerified,
        locale,
        timezone,
        carlysProfile,
      );
}
