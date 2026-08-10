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
  type MediaAsset,
  type Prisma,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export type ExerciseWithRelations = Exercise & {
  muscles: (ExerciseMuscle & { muscleGroup: MuscleGroup })[];
  equipment: (ExerciseEquipment & { equipment: Equipment })[];
  image: MediaAsset | null;
  mesh: MediaAsset | null;
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
  // Médias déposés depuis l'administration. Rien n'est embarqué dans l'app.
  image: true,
  mesh: true,
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
    const where = this.whereOf(filters);

    return this.prisma.exercise.findMany({
      where,
      include: RELATIONS,
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
      take: limit + 1,
      ...(cursor === undefined ? {} : { cursor: { id: cursor }, skip: 1 }),
    });
  }

  /** Nombre d'exercices que ces filtres retiennent, toutes pages confondues. */
  countMatching(filters: ListExercisesFilters): Promise<number> {
    return this.prisma.exercise.count({ where: this.whereOf(filters) });
  }

  /**
   * Critères d'une liste de catalogue.
   *
   * Extrait pour que le COMPTAGE et la PAGE partent exactement des mêmes
   * conditions : deux copies finiraient par diverger, et le compteur
   * annoncerait un nombre que la liste ne montrerait pas.
   */
  private whereOf(filters: ListExercisesFilters): Prisma.ExerciseWhereInput {
    return {
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
  }

  findPublishedByIdOrSlug(idOrSlug: string): Promise<ExerciseWithRelations | null> {
    const where = UUID_PATTERN.test(idOrSlug) ? { id: idOrSlug } : { slug: idOrSlug };
    return this.prisma.exercise.findFirst({
      where: { ...where, isPublished: true },
      include: RELATIONS,
    });
  }

  /**
   * Groupes musculaires qui ont au moins un exercice PUBLIÉ.
   *
   * La bibliothèque se parcourt par groupe : une catégorie vide s'ouvrirait
   * sur une liste vide, ce qui se lit comme une panne. Le cas n'est pas
   * théorique — une catégorie fraîchement créée depuis l'administration
   * n'a, par construction, aucun exercice.
   */
  listMuscleGroups(): Promise<MuscleGroup[]> {
    return this.prisma.muscleGroup.findMany({
      where: { exerciseLinks: { some: { exercise: { isPublished: true } } } },
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
