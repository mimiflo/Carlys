import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../nutrition/domain/entities/nutrition.dart';
import '../../../workout_program/domain/entities/training_goal.dart';

/// Habillage des options de l'onboarding : icône et sous-titre descriptif.
///
/// Les libellés viennent des enums du domaine (`NutritionGoal.label`,
/// `ActivityLevel.description`…) : aucun objectif ni niveau n'est inventé
/// ici. Les icônes absentes d'`AppIcons` reprennent le glyphe de la
/// maquette.

/// Ordre d'affichage de la maquette : la prise de muscle en tête.
const List<NutritionGoal> onboardingGoals = [
  NutritionGoal.gainMuscle,
  NutritionGoal.loseWeight,
  NutritionGoal.maintain,
];

IconData goalIcon(NutritionGoal goal) => switch (goal) {
  NutritionGoal.gainMuscle => AppIcons.workout,
  NutritionGoal.loseWeight => Icons.local_fire_department_rounded,
  NutritionGoal.maintain => Icons.self_improvement_rounded,
};

String goalSubtitle(NutritionGoal goal) => switch (goal) {
  NutritionGoal.gainMuscle => 'Surplus léger · volume élevé',
  NutritionGoal.loseWeight => 'Déficit maîtrisé · cardio',
  NutritionGoal.maintain => 'Régularité avant tout',
};

/// Un glyphe par objectif d'entraînement — l'ordre d'affichage est celui
/// de l'enum : du plus demandé (perte de gras, muscle) au plus spécialisé.
IconData trainingGoalIcon(TrainingGoal goal) => switch (goal) {
  TrainingGoal.fatLoss => Icons.local_fire_department_rounded,
  TrainingGoal.muscleGain => AppIcons.workout,
  TrainingGoal.recomposition => Icons.autorenew_rounded,
  TrainingGoal.hyrox => Icons.sports_score_rounded,
  TrainingGoal.marathon => Icons.directions_run_rounded,
  TrainingGoal.maintenance => Icons.balance_rounded,
  TrainingGoal.strength => AppIcons.trendingUp,
  TrainingGoal.calisthenics => AppIcons.exercises,
};

IconData sexIcon(BiologicalSex sex) => switch (sex) {
  BiologicalSex.male => Icons.male_rounded,
  BiologicalSex.female => Icons.female_rounded,
};

IconData activityIcon(ActivityLevel level) => switch (level) {
  ActivityLevel.sedentary => Icons.weekend_rounded,
  ActivityLevel.light => Icons.directions_walk_rounded,
  ActivityLevel.moderate => Icons.directions_run_rounded,
  ActivityLevel.active => AppIcons.workout,
  ActivityLevel.veryActive => Icons.bolt_rounded,
};
