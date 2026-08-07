/// DTO du catalogue — parsing manuel du JSON de l'API.
library;

import '../../domain/entities/exercise.dart';

MuscleGroupRef muscleGroupFromJson(Map<String, dynamic> json) => MuscleGroupRef(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
    );

EquipmentRef equipmentFromJson(Map<String, dynamic> json) => EquipmentRef(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
    );

ExerciseSummary exerciseSummaryFromJson(Map<String, dynamic> json) =>
    ExerciseSummary(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      difficulty: ExerciseDifficulty.fromApi(json['difficulty'] as String),
      kind: ExerciseKind.fromApi(json['type'] as String),
      isPremium: json['isPremium'] as bool,
      primaryMuscleGroup: json['primaryMuscleGroup'] == null
          ? null
          : muscleGroupFromJson(
              json['primaryMuscleGroup'] as Map<String, dynamic>,
            ),
      equipment: (json['equipment'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(equipmentFromJson)
          .toList(),
    );

ExerciseDetail exerciseDetailFromJson(Map<String, dynamic> json) {
  final summary = exerciseSummaryFromJson(json);
  return ExerciseDetail(
    id: summary.id,
    slug: summary.slug,
    name: summary.name,
    difficulty: summary.difficulty,
    kind: summary.kind,
    isPremium: summary.isPremium,
    primaryMuscleGroup: summary.primaryMuscleGroup,
    equipment: summary.equipment,
    description: json['description'] as String,
    instructions:
        (json['instructions'] as List<dynamic>).whereType<String>().toList(),
    tags: (json['tags'] as List<dynamic>).whereType<String>().toList(),
    muscles: (json['muscles'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(
          (link) => ExerciseMuscleLink(
            muscleGroup: muscleGroupFromJson(
              link['muscleGroup'] as Map<String, dynamic>,
            ),
            isPrimary: link['role'] == 'PRIMARY',
          ),
        )
        .toList(),
  );
}
