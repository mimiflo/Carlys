import {
  type Equipment as EquipmentContract,
  type ExerciseDetail,
  type ExerciseSummary,
  type MuscleGroup as MuscleGroupContract,
} from '@carlys/api-contracts';
import {
  type Equipment,
  ExerciseMuscleRole,
  type MediaAsset,
  type MuscleGroup,
} from '@prisma/client';
import { type ExerciseWithRelations } from '../infrastructure/exercises.repository';

/**
 * URL publique d'un média rattaché, ou `null`.
 *
 * La clé de stockage ne sort JAMAIS de l'API : l'application reçoit une
 * adresse, pas un chemin de bucket. Un média supprimé logiquement disparaît
 * ici — l'écran retombe sur son repli au lieu de servir une URL morte.
 */
function mediaUrl(media: MediaAsset | null, publicBaseUrl: string): string | null {
  if (media === null || media.deletedAt !== null) return null;
  return `${publicBaseUrl.replace(/\/+$/, '')}/${media.storageKey}`;
}

export function presentMuscleGroup(muscleGroup: MuscleGroup): MuscleGroupContract {
  return { id: muscleGroup.id, slug: muscleGroup.slug, name: muscleGroup.name };
}

export function presentEquipment(equipment: Equipment): EquipmentContract {
  return { id: equipment.id, slug: equipment.slug, name: equipment.name };
}

export function presentExerciseSummary(
  exercise: ExerciseWithRelations,
  publicBaseUrl: string,
): ExerciseSummary {
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
    imageUrl: mediaUrl(exercise.image, publicBaseUrl),
  };
}

export function presentExerciseDetail(
  exercise: ExerciseWithRelations,
  publicBaseUrl: string,
): ExerciseDetail {
  return {
    ...presentExerciseSummary(exercise, publicBaseUrl),
    description: exercise.description,
    instructions: exercise.instructions,
    tags: exercise.tags,
    muscles: exercise.muscles.map((link) => ({
      muscleGroup: presentMuscleGroup(link.muscleGroup),
      role: link.role,
    })),
    meshUrl: mediaUrl(exercise.mesh, publicBaseUrl),
  };
}
