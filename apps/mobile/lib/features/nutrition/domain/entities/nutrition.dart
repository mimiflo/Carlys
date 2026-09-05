/// Entités du domaine nutrition (immuables, écrites à la main).
///
/// Tous les calculs métaboliques sont faits CÔTÉ SERVEUR ; l'app collecte le
/// profil et affiche le rapport, jamais l'inverse.
library;

/// Sexe biologique — requis par la formule de Mifflin-St Jeor.
enum BiologicalSex {
  male('MALE', 'Homme'),
  female('FEMALE', 'Femme');

  const BiologicalSex(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static BiologicalSex? fromApi(String? value) {
    for (final sex in BiologicalSex.values) {
      if (sex.apiValue == value) {
        return sex;
      }
    }
    return null;
  }
}

/// Niveau d'activité physique hebdomadaire (facteur TDEE).
enum ActivityLevel {
  sedentary('SEDENTARY', 'Sédentaire', 'Peu ou pas d’exercice'),
  light('LIGHT', 'Légèrement actif', '1 à 3 séances par semaine'),
  moderate('MODERATE', 'Modérément actif', '3 à 5 séances par semaine'),
  active('ACTIVE', 'Actif', '6 à 7 séances par semaine'),
  veryActive('VERY_ACTIVE', 'Très actif', 'Physique quotidien intense');

  const ActivityLevel(this.apiValue, this.label, this.description);

  final String apiValue;
  final String label;
  final String description;

  static ActivityLevel? fromApi(String? value) {
    for (final level in ActivityLevel.values) {
      if (level.apiValue == value) {
        return level;
      }
    }
    return null;
  }
}

/// Objectif nutritionnel — module l'objectif calorique quotidien.
enum NutritionGoal {
  loseWeight('LOSE_WEIGHT', 'Perdre du poids'),
  maintain('MAINTAIN', 'Maintenir'),
  gainMuscle('GAIN_MUSCLE', 'Prendre du muscle');

  const NutritionGoal(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static NutritionGoal? fromApi(String? value) {
    for (final goal in NutritionGoal.values) {
      if (goal.apiValue == value) {
        return goal;
      }
    }
    return null;
  }
}

/// Catégorie d'IMC selon l'OMS.
enum BmiCategory {
  underweight('UNDERWEIGHT', 'Insuffisance pondérale'),
  normal('NORMAL', 'Corpulence normale'),
  overweight('OVERWEIGHT', 'Surpoids'),
  obese('OBESE', 'Obésité');

  const BmiCategory(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static BmiCategory fromApi(String value) => BmiCategory.values.firstWhere(
    (category) => category.apiValue == value,
    orElse: () => BmiCategory.normal,
  );
}

/// Champ manquant pour calculer le métabolisme.
enum MetabolismMissingField {
  sex('sex', 'Sexe biologique'),
  birthDate('birthDate', 'Date de naissance'),
  heightCm('heightCm', 'Taille'),
  activityLevel('activityLevel', 'Niveau d’activité'),
  weightKg('weightKg', 'Poids (mesure corporelle)');

  const MetabolismMissingField(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MetabolismMissingField? fromApi(String? value) {
    for (final field in MetabolismMissingField.values) {
      if (field.apiValue == value) {
        return field;
      }
    }
    return null;
  }
}

/// Profil métabolique effectif — le poids vient de la dernière mesure.
class MetabolicProfile {
  const MetabolicProfile({
    this.sex,
    this.birthDate,
    this.ageYears,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.goal,
  });

  final BiologicalSex? sex;
  final DateTime? birthDate;
  final int? ageYears;
  final double? heightCm;
  final double? weightKg;
  final ActivityLevel? activityLevel;
  final NutritionGoal? goal;
}

/// Résultats métaboliques calculés par le serveur.
class MetabolismResult {
  const MetabolismResult({
    required this.bmi,
    required this.bmiCategory,
    required this.bmrKcal,
    required this.tdeeKcal,
    required this.targetKcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.waterMl,
  });

  final double bmi;
  final BmiCategory bmiCategory;
  final int bmrKcal;
  final int tdeeKcal;
  final int targetKcal;
  final int proteinG;
  final int fatG;
  final int carbsG;
  final int waterMl;
}

/// Rapport complet : profil + champs manquants + métabolisme éventuel.
class MetabolismReport {
  const MetabolismReport({
    required this.profile,
    required this.missing,
    this.metabolism,
  });

  final MetabolicProfile profile;
  final List<MetabolismMissingField> missing;
  final MetabolismResult? metabolism;

  bool get isComplete => metabolism != null;
}

/// Mise à jour du profil métabolique — seuls les champs fournis sont envoyés.
class MetabolicProfileUpdate {
  const MetabolicProfileUpdate({
    this.sex,
    this.birthDate,
    this.heightCm,
    this.activityLevel,
    this.goal,
  });

  final BiologicalSex? sex;
  final DateTime? birthDate;
  final double? heightCm;
  final ActivityLevel? activityLevel;
  final NutritionGoal? goal;

  bool get isEmpty =>
      sex == null &&
      birthDate == null &&
      heightCm == null &&
      activityLevel == null &&
      goal == null;
}

/// Une entrée du journal alimentaire — ce que l'utilisateur dit avoir mangé.
///
/// C'est la moitié RÉELLE du « consommé / objectif » de l'accueil.
/// L'identifiant est un UUID généré sur l'appareil (création idempotente).
class MealEntry {
  const MealEntry({
    required this.id,
    required this.name,
    required this.kcal,
    required this.eatenAt,
    this.proteinG,
  });

  final String id;
  final String name;
  final int kcal;
  final int? proteinG;

  /// Instant de consommation, UTC — l'affichage est localisé.
  final DateTime eatenAt;
}
