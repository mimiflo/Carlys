import '../entities/carlys_profile.dart';

/// Choix du profil Carlys — le serveur est la source de vérité, la lecture
/// passe par le profil utilisateur (`AuthUser.carlysProfile`).
abstract class CarlysProfileRepository {
  /// Choisit (ou change) le profil. Rejouable à volonté : ce n'est pas un
  /// engagement, c'est une identité qui évolue.
  Future<void> choose(CarlysProfile profile);
}
