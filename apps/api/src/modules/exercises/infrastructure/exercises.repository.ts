import { Injectable } from '@nestjs/common';
import {
  type Equipment,
  type Exercise,
  type ExerciseDifficulty,
  type ExerciseEquipment,
  type ExerciseMuscle,
  ExerciseMuscleRole,
  type ExerciseType,
  type MuscleGroup,
  type Prisma,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export type ExerciseWithRelations = Exercise & {
  muscles: (ExerciseMuscle & { muscleGroup: MuscleGroup })[];
  equipment: (ExerciseEquipment & { equipment: Equipment })[];
};

export interface ListExercisesFilters {
  search?: string;
  muscleGroupSlug?: string;
  equipmentSlug?: string;
  difficulty?: ExerciseDifficulty;
  type?: ExerciseType;
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const RELATIONS = {
  muscles: { include: { muscleGroup: true }, orderBy: { role: 'asc' as const } },
  equipment: { include: { equipment: true } },
};

/** Accès Prisma du catalogue — uniquement des exercices publiés. */
@Injectable()
export class ExercisesRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Page de catalogue triée par nom (départage par id), pagination par
   * curseur : retourne `limit + 1` éléments pour détecter la page suivante.
   */
  listPage(
    filters: ListExercisesFilters,
    limit: number,
    cursor?: string,
  ): Promise<ExerciseWithRelations[]> {
    const where: Prisma.ExerciseWhereInput = {
      isPublished: true,
      ...(filters.difficulty === undefined ? {} : { difficulty: filters.difficulty }),
      ...(filters.type === undefined ? {} : { type: filters.type }),
      ...(filters.search === undefined
        ? {}
        : {
            OR: [
              { name: { contains: filters.search, mode: 'insensitive' } },
              { tags: { has: filters.search.toLowerCase() } },
            ],
          }),
      ...(filters.muscleGroupSlug === undefined
        ? {}
        : { muscles: { some: { muscleGroup: { slug: filters.muscleGroupSlug } } } }),
      ...(filters.equipmentSlug === undefined
        ? {}
        : { equipment: { some: { equipment: { slug: filters.equipmentSlug } } } }),
    };

    return this.prisma.exercise.findMany({
      where,
      include: RELATIONS,
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
      take: limit + 1,
      ...(cursor === undefined ? {} : { cursor: { id: cursor }, skip: 1 }),
    });
  }

  findPublishedByIdOrSlug(idOrSlug: string): Promise<ExerciseWithRelations | null> {
    const where = UUID_PATTERN.test(idOrSlug) ? { id: idOrSlug } : { slug: idOrSlug };
    return this.prisma.exercise.findFirst({
      where: { ...where, isPublished: true },
      include: RELATIONS,
    });
  }

  listMuscleGroups(): Promise<MuscleGroup[]> {
    return this.prisma.muscleGroup.findMany({
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  listEquipment(): Promise<Equipment[]> {
    return this.prisma.equipment.findMany({ orderBy: { name: 'asc' } });
  }

  /** Rôle primaire d'abord (l'enum PRIMARY précède SECONDARY). */
  static primaryFirst(role: ExerciseMuscleRole): number {
    return role === ExerciseMuscleRole.PRIMARY ? 0 : 1;
  }
}
