/// Entités du catalogue d'exercices (immuables, écrites à la main —
/// migration Freezed prévue quand la génération de code entrera en CI).
library;

enum ExerciseDifficulty {
  beginner('Débutant'),
  intermediate('Intermédiaire'),
  advanced('Avancé');

  const ExerciseDifficulty(this.label);

  final String label;

  static ExerciseDifficulty fromApi(String value) => switch (value) {
        'BEGINNER' => ExerciseDifficulty.beginner,
        'INTERMEDIATE' => ExerciseDifficulty.intermediate,
        'ADVANCED' => ExerciseDifficulty.advanced,
        _ => ExerciseDifficulty.beginner,
      };

  String get apiValue => switch (this) {
        ExerciseDifficulty.beginner => 'BEGINNER',
        ExerciseDifficulty.intermediate => 'INTERMEDIATE',
        ExerciseDifficulty.advanced => 'ADVANCED',
      };
}

enum ExerciseKind {
  strength('Renforcement'),
  cardio('Cardio'),
  mobility('Mobilité'),
  stretching('Étirement');

  const ExerciseKind(this.label);

  final String label;

  static ExerciseKind fromApi(String value) => switch (value) {
        'STRENGTH' => ExerciseKind.strength,
        'CARDIO' => ExerciseKind.cardio,
        'MOBILITY' => ExerciseKind.mobility,
        'STRETCHING' => ExerciseKind.stretching,
        _ => ExerciseKind.strength,
      };
}

class MuscleGroupRef {
  const MuscleGroupRef({
    required this.id,
    required this.slug,
    required this.name,
  });

  final String id;
  final String slug;
  final String name;

  @override
  bool operator ==(Object other) => other is MuscleGroupRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class EquipmentRef {
  const EquipmentRef({
    required this.id,
    required this.slug,
    required this.name,
  });

  final String id;
  final String slug;
  final String name;
}

class ExerciseSummary {
  const ExerciseSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.difficulty,
    required this.kind,
    required this.isPremium,
    required this.primaryMuscleGroup,
    required this.equipment,
  });

  final String id;
  final String slug;
  final String name;
  final ExerciseDifficulty difficulty;
  final ExerciseKind kind;
  final bool isPremium;
  final MuscleGroupRef? primaryMuscleGroup;
  final List<EquipmentRef> equipment;
}

class ExerciseMuscleLink {
  const ExerciseMuscleLink({
    required this.muscleGroup,
    required this.isPrimary,
  });

  final MuscleGroupRef muscleGroup;
  final bool isPrimary;
}

class ExerciseDetail extends ExerciseSummary {
  const ExerciseDetail({
    required super.id,
    required super.slug,
    required super.name,
    required super.difficulty,
    required super.kind,
    required super.isPremium,
    required super.primaryMuscleGroup,
    required super.equipment,
    required this.description,
    required this.instructions,
    required this.tags,
    required this.muscles,
  });

  final String description;
  final List<String> instructions;
  final List<String> tags;
  final List<ExerciseMuscleLink> muscles;
}

/// Page de catalogue (pagination par curseur).
class ExercisesPage {
  const ExercisesPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<ExerciseSummary> items;
  final String? nextCursor;
  final bool hasMore;
}
