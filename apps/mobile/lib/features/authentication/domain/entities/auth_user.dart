import '../../../carlys_profile/domain/entities/carlys_profile.dart';
import '../../../mentor/domain/entities/mentor_style.dart';
import '../../../workout_program/domain/entities/training_goal.dart';

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
    this.mentorStyle,
    this.trainingGoal,
    this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;
  final String locale;
  final String timezone;

  /// Identité Carlys choisie — null tant qu'elle ne l'a pas été.
  final CarlysProfile? carlysProfile;

  /// Voix du Mentor choisie — null tant qu'elle ne l'a pas été.
  final MentorStyle? mentorStyle;

  /// Objectif d'entraînement choisi — null tant qu'il ne l'a pas été.
  final TrainingGoal? trainingGoal;

  /// Création du compte — « Membre depuis » sur le profil.
  ///
  /// Nullable alors que l'API la sert toujours : la date n'est qu'une ligne
  /// d'affichage, et une valeur absente ou illisible doit effacer la ligne,
  /// jamais faire échouer la connexion.
  final DateTime? createdAt;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName &&
      other.emailVerified == emailVerified &&
      other.locale == locale &&
      other.timezone == timezone &&
      other.carlysProfile == carlysProfile &&
      other.mentorStyle == mentorStyle &&
      other.trainingGoal == trainingGoal &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    email,
    displayName,
    emailVerified,
    locale,
    timezone,
    carlysProfile,
    mentorStyle,
    trainingGoal,
    createdAt,
  );
}
