import {
  type Equipment as EquipmentContract,
  type ExerciseDetail,
  type ExerciseSummary,
  type MuscleGroup as MuscleGroupContract,
} from '@carlys/api-contracts';
import { type Equipment, ExerciseMuscleRole, type MuscleGroup } from '@prisma/client';
import { type ExerciseWithRelations } from '../infrastructure/exercises.repository';

export function presentMuscleGroup(muscleGroup: MuscleGroup): MuscleGroupContract {
  return { id: muscleGroup.id, slug: muscleGroup.slug, name: muscleGroup.name };
}

export function presentEquipment(equipment: Equipment): EquipmentContract {
  return { id: equipment.id, slug: equipment.slug, name: equipment.name };
}

export function presentExerciseSummary(exercise: ExerciseWithRelations): ExerciseSummary {
  const primary = exercise.muscles.find((link) => link.role === ExerciseMuscleRole.PRIMARY);
  return {
    id: exercise.id,
    slug: exercise.slug,
    name: exercise.name,
    difficulty: exercise.difficulty,
    type: exercise.type,
    isPremium: exercise.isPremium,
    primaryMuscleGroup: primary === undefined ? null : presentMuscleGroup(primary.muscleGroup),
    equipment: exercise.equipment.map((link) => presentEquipment(link.equipment)),
  };
}

export function presentExerciseDetail(exercise: ExerciseWithRelations): ExerciseDetail {
  return {
    ...presentExerciseSummary(exercise),
    description: exercise.description,
    instructions: exercise.instructions,
    tags: exercise.tags,
    muscles: exercise.muscles.map((link) => ({
      muscleGroup: presentMuscleGroup(link.muscleGroup),
      role: link.role,
    })),
  };
}
