import '../../carlys_profile/domain/entities/carlys_profile.dart';
import '../../nutrition/domain/entities/nutrition.dart';

/// Réponses données pendant l'onboarding.
///
/// Elles sont collectées AVANT que le compte n'existe : on les conserve
/// localement puis on les enregistre sur le profil dès qu'une session est
/// ouverte. Aucune donnée sensible ici (préférences de profil uniquement).
class OnboardingAnswers {
  const OnboardingAnswers({
    this.carlysProfile,
    this.goal,
    this.sex,
    this.birthDate,
    this.heightCm,
    this.activityLevel,
  });

  /// Relecture depuis les préférences locales — toute valeur inconnue est
  /// ignorée plutôt que devinée.
  factory OnboardingAnswers.fromStorage(Map<String, Object?> json) {
    final birthDate = json[_birthDateKey];
    final heightCm = json[_heightKey];

    return OnboardingAnswers(
      carlysProfile: CarlysProfile.fromWire(json[_carlysProfileKey] as String?),
      goal: NutritionGoal.fromApi(json[_goalKey] as String?),
      sex: BiologicalSex.fromApi(json[_sexKey] as String?),
      birthDate:
          birthDate is String ? DateTime.tryParse(birthDate)?.toUtc() : null,
      heightCm: heightCm is num ? heightCm.toDouble() : null,
      activityLevel: ActivityLevel.fromApi(json[_activityKey] as String?),
    );
  }

  static const String _carlysProfileKey = 'profilCarlys';
  static const String _goalKey = 'objectif';
  static const String _sexKey = 'sexe';
  static const String _birthDateKey = 'naissance';
  static const String _heightKey = 'tailleCm';
  static const String _activityKey = 'activite';

  /// Identité Carlys choisie — enregistrée via `PATCH /users/me`, pas sur le
  /// profil métabolique.
  final CarlysProfile? carlysProfile;

  final NutritionGoal? goal;
  final BiologicalSex? sex;

  /// Toujours en UTC (convention du dépôt).
  final DateTime? birthDate;
  final double? heightCm;
  final ActivityLevel? activityLevel;

  /// Au moins une réponse MÉTABOLIQUE : c'est elle qui justifie un
  /// enregistrement sur le profil nutritionnel.
  bool get hasMetabolicAnswers =>
      goal != null ||
      sex != null ||
      birthDate != null ||
      heightCm != null ||
      activityLevel != null;

  bool get isEmpty => !hasMetabolicAnswers && carlysProfile == null;

  MetabolicProfileUpdate toProfileUpdate() => MetabolicProfileUpdate(
        goal: goal,
        sex: sex,
        birthDate: birthDate,
        heightCm: heightCm,
        activityLevel: activityLevel,
      );

  Map<String, Object?> toStorage() => {
        if (carlysProfile != null) _carlysProfileKey: carlysProfile!.wire,
        if (goal != null) _goalKey: goal!.apiValue,
        if (sex != null) _sexKey: sex!.apiValue,
        if (birthDate != null)
          _birthDateKey: birthDate!.toUtc().toIso8601String(),
        if (heightCm != null) _heightKey: heightCm,
        if (activityLevel != null) _activityKey: activityLevel!.apiValue,
      };
}
