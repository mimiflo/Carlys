import '../../domain/entities/nutrition.dart';

/// Lecture du rapport métabolique servi par `GET /nutrition/metabolism`.
///
/// Extrait du repository parce que la traduction JSON → entités y occupait à
/// elle seule plus de quarante lignes, ce que la règle du dépôt refuse à une
/// méthode de repository. Ce sont des fonctions PURES : elles ne connaissent
/// ni Dio, ni l'enveloppe de réponse, et se relisent sans dérouler un appel
/// réseau.
MetabolicProfile metabolicProfileFromJson(Map<String, dynamic> json) {
  return MetabolicProfile(
    sex: BiologicalSex.fromApi(json['sex'] as String?),
    birthDate: json['birthDate'] == null
        ? null
        : DateTime.parse(json['birthDate'] as String),
    ageYears: (json['ageYears'] as num?)?.toInt(),
    heightCm: (json['heightCm'] as num?)?.toDouble(),
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    activityLevel: ActivityLevel.fromApi(json['activityLevel'] as String?),
    goal: NutritionGoal.fromApi(json['goal'] as String?),
  );
}

/// Les champs qu'il manque au profil pour que le serveur puisse calculer.
///
/// Un libellé inconnu de cette version de l'application est IGNORÉ, jamais
/// traité comme une panne : un serveur plus récent peut en nommer un que le
/// client ne sait pas encore afficher.
List<MetabolismMissingField> missingFieldsFromJson(List<dynamic>? json) {
  return (json ?? const [])
      .whereType<String>()
      .map(MetabolismMissingField.fromApi)
      .whereType<MetabolismMissingField>()
      .toList();
}

/// Le calcul lui-même. `null` tant que le profil est incomplet : le serveur
/// ne sert alors aucun chiffre, et l'écran n'en invente pas.
MetabolismResult? metabolismResultFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }
  return MetabolismResult(
    bmi: (json['bmi'] as num).toDouble(),
    bmiCategory: BmiCategory.fromApi(json['bmiCategory'] as String),
    bmrKcal: (json['bmrKcal'] as num).toInt(),
    tdeeKcal: (json['tdeeKcal'] as num).toInt(),
    targetKcal: (json['targetKcal'] as num).toInt(),
    // Absent d'un serveur antérieur au plancher : on retombe alors sur
    // « pas relevée », ce qui est exactement ce que ce serveur-là voulait
    // dire. Une absence n'est pas une panne, comme pour les champs manquants
    // juste au-dessus.
    targetKcalFloored: json['targetKcalFloored'] as bool? ?? false,
    proteinG: (json['proteinG'] as num).toInt(),
    fatG: (json['fatG'] as num).toInt(),
    carbsG: (json['carbsG'] as num).toInt(),
    waterMl: (json['waterMl'] as num).toInt(),
  );
}
