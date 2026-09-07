import { Injectable } from '@nestjs/common';
import { type Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export type AdminExerciseRow = Prisma.ExerciseGetPayload<{
  include: {
    muscles: { include: { muscleGroup: true } };
    equipment: { include: { equipment: true } };
    image: true;
    mesh: true;
  };
}>;

export interface MuscleGroupRow {
  id: string;
  slug: string;
  name: string;
  sortOrder: number;
  primaryExercisesCount: number;
  exercisesCount: number;
}

/**
 * Le CATALOGUE vu du back-office : les exercices, publiés comme dépubliés, et
 * le classement (groupes musculaires, matériels) qui les range.
 */
@Injectable()
export class AdminCatalogRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Exercices du back-office : **publiés ET non publiés**.
   *
   * Le catalogue mobile ne sert que le publié, par construction — c'est
   * précisément ce qu'il faut ne PAS faire ici : un exercice dépublié n'est
   * visible nulle part ailleurs, et il faut bien pouvoir le republier.
   */
  listExercises(
    search: string | undefined,
    limit: number,
    cursor?: string,
    includeDeleted = false,
  ): Promise<AdminExerciseRow[]> {
    const trimmed = search?.trim();
    return this.prisma.exercise.findMany({
      where: {
        ...(includeDeleted ? {} : { deletedAt: null }),
        ...(trimmed === undefined || trimmed.length === 0
          ? {}
          : {
              OR: [
                { name: { contains: trimmed, mode: 'insensitive' } },
                { slug: { contains: trimmed, mode: 'insensitive' } },
              ],
            }),
      },
      include: {
        muscles: { include: { muscleGroup: true }, orderBy: { role: 'asc' } },
        equipment: { include: { equipment: true } },
        image: true,
        mesh: true,
      },
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
      take: limit + 1,
      ...(cursor === undefined ? {} : { cursor: { id: cursor }, skip: 1 }),
    });
  }

  setExercisePublication(exerciseId: string, isPublished: boolean): Promise<boolean> {
    // Un exercice SUPPRIMÉ ne se republie pas : il faut d'abord le restaurer.
    return this.prisma.exercise
      .updateMany({ where: { id: exerciseId, deletedAt: null }, data: { isPublished } })
      .then((result) => result.count > 0);
  }

  /**
   * Retire l'exercice du catalogue — sans effacer une ligne d'historique.
   *
   * `isPublished` tombe en même temps, et c'est ce qui fait tout le travail :
   * le catalogue mobile, le coach et les modèles filtrent déjà sur ce drapeau.
   * Aucune de ces requêtes n'a donc à connaître `deletedAt`.
   */
  softDeleteExercise(exerciseId: string): Promise<boolean> {
    return this.prisma.exercise
      .updateMany({
        where: { id: exerciseId, deletedAt: null },
        data: { deletedAt: new Date(), isPublished: false },
      })
      .then((result) => result.count > 0);
  }

  /** Restaure un exercice supprimé — DÉPUBLIÉ : la republication se décide. */
  restoreExercise(exerciseId: string): Promise<boolean> {
    return this.prisma.exercise
      .updateMany({
        where: { id: exerciseId, deletedAt: { not: null } },
        data: { deletedAt: null },
      })
      .then((result) => result.count > 0);
  }

  findExercise(exerciseId: string): Promise<AdminExerciseRow | null> {
    return this.prisma.exercise.findUnique({
      where: { id: exerciseId },
      include: {
        muscles: { include: { muscleGroup: true }, orderBy: { role: 'asc' } },
        equipment: { include: { equipment: true } },
        image: true,
        mesh: true,
      },
    });
  }

  /**
   * Remplace EN BLOC les rattachements d'un exercice, dans une transaction.
   *
   * Sans transaction, un échec au milieu laisserait un exercice sans aucun
   * groupe musculaire — donc introuvable dans la bibliothèque, qui se parcourt
   * par groupe.
   */
  async setExerciseCategories(
    exerciseId: string,
    primaryMuscleGroupId: string,
    secondaryMuscleGroupIds: string[],
    equipmentIds: string[],
  ): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.exerciseMuscle.deleteMany({ where: { exerciseId } }),
      this.prisma.exerciseMuscle.createMany({
        data: [
          { exerciseId, muscleGroupId: primaryMuscleGroupId, role: 'PRIMARY' as const },
          ...secondaryMuscleGroupIds.map((muscleGroupId) => ({
            exerciseId,
            muscleGroupId,
            role: 'SECONDARY' as const,
          })),
        ],
      }),
      this.prisma.exerciseEquipment.deleteMany({ where: { exerciseId } }),
      this.prisma.exerciseEquipment.createMany({
        data: equipmentIds.map((equipmentId) => ({ exerciseId, equipmentId })),
      }),
      this.prisma.exercise.update({ where: { id: exerciseId }, data: { updatedAt: new Date() } }),
    ]);
  }

  // ── Catégories (groupes musculaires) ────────────────────────────────────

  async listMuscleGroups(): Promise<MuscleGroupRow[]> {
    const groups = await this.prisma.muscleGroup.findMany({
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      include: {
        exerciseLinks: {
          where: { exercise: { deletedAt: null } },
          select: { role: true },
        },
      },
    });
    return groups.map((group) => ({
      id: group.id,
      slug: group.slug,
      name: group.name,
      sortOrder: group.sortOrder,
      exercisesCount: group.exerciseLinks.length,
      primaryExercisesCount: group.exerciseLinks.filter((link) => link.role === 'PRIMARY').length,
    }));
  }

  findMuscleGroupBySlug(slug: string): Promise<{ id: string } | null> {
    return this.prisma.muscleGroup.findUnique({ where: { slug }, select: { id: true } });
  }

  findMuscleGroupIdsBySlugs(slugs: string[]): Promise<{ id: string; slug: string }[]> {
    return this.prisma.muscleGroup.findMany({
      where: { slug: { in: slugs } },
      select: { id: true, slug: true },
    });
  }

  listEquipment(): Promise<{ id: string; slug: string; name: string }[]> {
    return this.prisma.equipment.findMany({
      orderBy: { name: 'asc' },
      select: { id: true, slug: true, name: true },
    });
  }

  findEquipmentIdsBySlugs(slugs: string[]): Promise<{ id: string; slug: string }[]> {
    return this.prisma.equipment.findMany({
      where: { slug: { in: slugs } },
      select: { id: true, slug: true },
    });
  }

  createMuscleGroup(slug: string, name: string, sortOrder: number): Promise<{ id: string }> {
    return this.prisma.muscleGroup.create({
      data: { slug, name, sortOrder },
      select: { id: true },
    });
  }

  updateMuscleGroup(id: string, data: { name?: string; sortOrder?: number }): Promise<boolean> {
    return this.prisma.muscleGroup
      .updateMany({ where: { id }, data })
      .then((result) => result.count > 0);
  }

  deleteMuscleGroup(id: string): Promise<boolean> {
    return this.prisma.muscleGroup.deleteMany({ where: { id } }).then((result) => result.count > 0);
  }
}
