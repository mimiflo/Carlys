import { Injectable } from '@nestjs/common';
import {
  Prisma,
  type WorkoutTemplate,
  type WorkoutTemplateExercise,
  type WorkoutTemplateSet,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

/** Modèle complet, exercices et séries prévues ordonnés par position. */
export type TemplateWithContent = WorkoutTemplate & {
  exercises: (WorkoutTemplateExercise & { sets: WorkoutTemplateSet[] })[];
};

/** Modèle allégé pour la liste : on ne charge jamais les séries prévues. */
export type TemplateWithCounts = WorkoutTemplate & {
  exercises: { exerciseName: string; _count: { sets: number } }[];
};

export interface ReplaceTemplateInput {
  id: string;
  userId: string;
  name: string;
  notes: string | null;
  estimatedDurationMinutes: number | null;
  exercises: Prisma.WorkoutTemplateExerciseCreateManyInput[];
  sets: Prisma.WorkoutTemplateSetCreateManyInput[];
}

const TEMPLATE_CONTENT = {
  exercises: {
    orderBy: { position: 'asc' as const },
    include: { sets: { orderBy: { position: 'asc' as const } } },
  },
};

const TEMPLATE_COUNTS = {
  exercises: {
    orderBy: { position: 'asc' as const },
    select: { exerciseName: true, _count: { select: { sets: true } } },
  },
};

/**
 * Accès Prisma des modèles de séance. Aucune requête n'est filtrée par
 * `userId` ici : c'est le service qui décide 404 (inconnu / supprimé /
 * appartenant à autrui) ou 409 (id déjà pris par un autre utilisateur).
 */
@Injectable()
export class WorkoutTemplatesRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Modèle brut, supprimé ou non : le service tranche la visibilité. */
  findTemplateById(id: string): Promise<TemplateWithContent | null> {
    return this.prisma.workoutTemplate.findUnique({
      where: { id },
      include: TEMPLATE_CONTENT,
    });
  }

  listTemplatesPage(userId: string, limit: number, cursor?: string): Promise<TemplateWithCounts[]> {
    return this.prisma.workoutTemplate.findMany({
      where: { userId, deletedAt: null },
      include: TEMPLATE_COUNTS,
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursor === undefined ? {} : { cursor: { id: cursor }, skip: 1 }),
    });
  }

  /**
   * Écriture unique : fait converger le modèle vers l'état décrit.
   * Le contenu (lignes et séries prévues) est remplacé PHYSIQUEMENT dans une
   * transaction — il n'est pas de l'historique, rien ne le référence.
   * `lastUsedAt` et `deletedAt` ne sont jamais touchés ici.
   */
  async replaceTemplate(input: ReplaceTemplateInput): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await tx.workoutTemplate.upsert({
        where: { id: input.id },
        create: {
          id: input.id,
          userId: input.userId,
          name: input.name,
          notes: input.notes,
          estimatedDurationMinutes: input.estimatedDurationMinutes,
        },
        update: {
          name: input.name,
          notes: input.notes,
          estimatedDurationMinutes: input.estimatedDurationMinutes,
        },
      });
      // Cascade : supprimer les lignes emporte leurs séries prévues.
      await tx.workoutTemplateExercise.deleteMany({ where: { templateId: input.id } });
      await tx.workoutTemplateExercise.createMany({ data: input.exercises });
      await tx.workoutTemplateSet.createMany({ data: input.sets });
    });
  }

  softDeleteTemplate(id: string): Promise<void> {
    return this.prisma.workoutTemplate
      .update({ where: { id }, data: { deletedAt: new Date() } })
      .then(() => undefined);
  }

  /**
   * Noms des exercices PUBLIÉS parmi les identifiants demandés, en une requête.
   * Un exercice absent (inconnu ou dépublié) n'apparaît pas dans la table.
   */
  async publishedExerciseNames(exerciseIds: string[]): Promise<Map<string, string>> {
    if (exerciseIds.length === 0) {
      return new Map();
    }
    const exercises = await this.prisma.exercise.findMany({
      where: { id: { in: exerciseIds }, isPublished: true },
      select: { id: true, name: true },
    });
    return new Map(exercises.map((exercise) => [exercise.id, exercise.name]));
  }

  /** Modèle lançable : à cet utilisateur et non supprimé. Sinon null. */
  findLaunchableTemplate(
    userId: string,
    templateId: string,
  ): Promise<{ id: string; name: string } | null> {
    return this.prisma.workoutTemplate.findFirst({
      where: { id: templateId, userId, deletedAt: null },
      select: { id: true, name: true },
    });
  }
}
