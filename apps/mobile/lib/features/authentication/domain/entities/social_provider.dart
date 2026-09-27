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

/// Le nom d'un compte Apple ou Google, tel que le serveur l'accepte : de 1 à
/// 60 POINTS DE CODE, blancs découpés (`SocialLoginDto`, contrat
/// `socialLoginRequestSchema`). `null` quand il ne reste rien.
///
/// Ce nom n'est qu'une courtoisie : il ne sert qu'à nommer un compte neuf.
/// Mais le serveur valide TOUT le corps avant de regarder si le compte
/// existe, et Google renvoie le nom à CHAQUE connexion : un nom de 61
/// caractères (« Maria Fernanda de los Angeles Castellanos Rodriguez y
/// Almeida ») faisait refuser la connexion en 400, pour toujours, sans issue
/// par Google. Couper vaut mieux que refuser d'entrer.
String? socialDisplayName(String? raw) {
  final nom = raw?.trim() ?? '';
  if (nom.isEmpty) return null;
  final runes = nom.runes;
  if (runes.length <= socialDisplayNameMaxLength) return nom;
  final coupe = String.fromCharCodes(
    runes.take(socialDisplayNameMaxLength),
  ).trim();
  return coupe.isEmpty ? null : coupe;
}

/// Borne du serveur pour [socialDisplayName].
const int socialDisplayNameMaxLength = 60;
