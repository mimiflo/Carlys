/// Les 4 profils Carlys : des IDENTITÉS d'usage — jamais des niveaux.
///
/// Un débutant peut être Stratège, un sportif avancé Challenger, et l'on
/// évolue d'un profil à l'autre à tout moment. Le choix vit sur le profil
/// serveur (`PATCH /users/me`), nul tant qu'il n'a pas été fait.
enum CarlysProfile {
  constructeur('CONSTRUCTEUR'),
  challenger('CHALLENGER'),
  athlete('ATHLETE'),
  stratege('STRATEGE');

  const CarlysProfile(this.wire);

  /// Valeur échangée avec l'API.
  final String wire;

  /// Null pour une valeur absente OU inconnue : un serveur plus récent qui
  /// ajouterait un profil ne doit pas faire planter les anciens clients.
  static CarlysProfile? fromWire(String? wire) {
    for (final profile in values) {
      if (profile.wire == wire) {
        return profile;
      }
    }
    return null;
  }
}
