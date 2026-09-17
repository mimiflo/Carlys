import '../entities/mentor_style.dart';

/// Choix de la voix du Mentor — le serveur est la source de vérité, la
/// lecture passe par le profil utilisateur (`AuthUser.mentorStyle`).
abstract class MentorRepository {
  /// Choisit (ou change) la voix. Rejouable à volonté : une voix n'est pas
  /// un engagement, elle s'essaie.
  Future<void> chooseStyle(MentorStyle style);
}
