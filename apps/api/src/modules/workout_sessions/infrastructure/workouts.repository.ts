import { Injectable } from '@nestjs/common';
import { Prisma, type WorkoutSession, type WorkoutSet, WorkoutSessionStatus } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export type SessionWithSets = WorkoutSession & { sets: WorkoutSet[] };

const ACTIVE_SETS = {
  sets: {
    where: { deletedAt: null },
    orderBy: [{ position: 'asc' as const }, { completedAt: 'asc' as const }],
  },
};

/** Accès Prisma des séances — toutes les requêtes sont scoppées à un userId. */
@Injectable()
export class WorkoutsRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Création idempotente : l'id vient de l'appareil. Retourne null si l'id existe déjà. */
  async createSession(data: Prisma.WorkoutSessionUncheckedCreateInput): Promise<boolean> {
    try {
      await this.prisma.workoutSession.create({ data });
      return true;
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return false;
      }
      throw error;
    }
  }

  findSessionById(id: string): Promise<SessionWithSets | null> {
    return this.prisma.workoutSession.findFirst({
      where: { id, deletedAt: null },
      include: ACTIVE_SETS,
    });
  }

  listSessionsPage(userId: string, limit: number, cursor?: string): Promise<SessionWithSets[]> {
    return this.prisma.workoutSession.findMany({
      where: { userId, deletedAt: null },
      include: ACTIVE_SETS,
      orderBy: [{ startedAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursor === undefined ? {} : { cursor: { id: cursor }, skip: 1 }),
    });
  }

  updateSession(
    id: string,
    data: Prisma.WorkoutSessionUncheckedUpdateInput,
  ): Promise<SessionWithSets> {
    return this.prisma.workoutSession.update({
      where: { id },
      data,
      include: ACTIVE_SETS,
    });
  }

  /** Clôture conditionnelle : n'aboutit que si la séance est encore en cours. */
  async transitionStatus(
    id: string,
    to: WorkoutSessionStatus,
    data: Prisma.WorkoutSessionUncheckedUpdateManyInput,
  ): Promise<boolean> {
    const updated = await this.prisma.workoutSession.updateMany({
      where: { id, status: WorkoutSessionStatus.IN_PROGRESS, deletedAt: null },
      data: { ...data, status: to },
    });
    return updated.count === 1;
  }

  /** Création idempotente d'une série. Retourne false si l'id existe déjà. */
  async createSet(data: Prisma.WorkoutSetUncheckedCreateInput): Promise<boolean> {
    try {
      await this.prisma.workoutSet.create({ data });
      return true;
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return false;
      }
      throw error;
    }
  }

  findSetById(id: string): Promise<(WorkoutSet & { session: WorkoutSession }) | null> {
    return this.prisma.workoutSet.findUnique({
      where: { id },
      include: { session: true },
    });
  }

  updateSet(id: string, data: Prisma.WorkoutSetUncheckedUpdateInput): Promise<WorkoutSet> {
    return this.prisma.workoutSet.update({ where: { id }, data });
  }

  softDeleteSet(id: string): Promise<void> {
    return this.prisma.workoutSet
      .update({ where: { id }, data: { deletedAt: new Date() } })
      .then(() => undefined);
  }

  exercisePublishedName(exerciseId: string): Promise<string | null> {
    return this.prisma.exercise
      .findFirst({ where: { id: exerciseId, isPublished: true }, select: { name: true } })
      .then((exercise) => exercise?.name ?? null);
  }
}
