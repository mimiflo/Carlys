/// Fournisseurs de connexion sociale proposés par Carlys.
///
/// Deux, et seulement deux : Apple et Google. Apple est OBLIGATOIRE sur iOS
/// dès lors qu'un autre fournisseur tiers est proposé (règle de l'App Store).
enum SocialProvider {
  apple('Apple'),
  google('Google');

  const SocialProvider(this.label);

  /// Nom affiché — et nom de marque, donc jamais traduit.
  final String label;

  /// Valeur attendue par l'API (`POST /auth/social`).
  String get wireName => name;
}
