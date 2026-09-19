import { Injectable } from '@nestjs/common';
import {
  Prisma,
  type WorkoutSession,
  type WorkoutSessionPlanItem,
  type WorkoutSet,
  WorkoutSessionStatus,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export type SessionWithSets = WorkoutSession & {
  sets: WorkoutSet[];
  planItems: WorkoutSessionPlanItem[];
};

/** Une séance vue par l'historique — voir [SUMMARY_SETS]. */
export type SessionSummaryRow = WorkoutSession & {
  sets: Pick<WorkoutSet, 'reps' | 'weightKg'>[];
};

const ACTIVE_SETS = {
  sets: {
    where: { deletedAt: null },
    orderBy: [{ position: 'asc' as const }, { completedAt: 'asc' as const }],
  },
  planItems: {
    orderBy: [{ exercisePosition: 'asc' as const }, { setPosition: 'asc' as const }],
  },
};

/**
 * Ce qu'une ligne d'HISTORIQUE lit d'une séance : le volume et le nombre de
 * séries, rien d'autre.
 *
 * La liste partageait l'include du DÉTAIL. Elle rapatriait donc, pour chaque
 * séance d'une page, le plan complet — jusqu'à 30 exercices × 20 séries, soit
 * 600 lignes que le résumé ne regarde jamais — et toutes les colonnes des
 * séries alors qu'il n'en somme que deux. Le tri des séries est abandonné
 * lui aussi : une somme et un compte ne dépendent pas de l'ordre.
 */
const SUMMARY_SETS = {
  sets: {
    where: { deletedAt: null },
    select: { reps: true as const, weightKg: true as const },
  },
};

/** Accès Prisma des séances — toutes les requêtes sont scoppées à un userId. */
@Injectable()
export class WorkoutsRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Création idempotente : l'id vient de l'appareil. Retourne false si l'id
   * existe déjà. Quand la séance vient d'un modèle, le dernier lancement de
   * celui-ci est daté DANS LA MÊME TRANSACTION : un rejeu, qui échoue sur la
   * clé primaire, ne redate donc jamais le modèle.
   *
   * Le PLAN suit le même sort : écrit dans cette transaction, il est donc
   * annulé avec elle par un rejeu — jamais dupliqué, jamais réécrit par une
   * requête plus ancienne qui arriverait après coup.
   */
  async createSession(
    data: Prisma.WorkoutSessionUncheckedCreateInput,
    touchTemplate?: { templateId: string; userId: string; lastUsedAt: Date },
    planItems: Prisma.WorkoutSessionPlanItemUncheckedCreateInput[] = [],
  ): Promise<boolean> {
    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.workoutSession.create({ data });
        if (planItems.length > 0) {
          await tx.workoutSessionPlanItem.createMany({ data: planItems });
        }
        if (touchTemplate !== undefined) {
          await tx.workoutTemplate.updateMany({
            where: { id: touchTemplate.templateId, userId: touchTemplate.userId, deletedAt: null },
            data: { lastUsedAt: touchTemplate.lastUsedAt },
          });
        }
      });
      return true;
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return false;
      }
      throw error;
    }
  }

  /**
   * Apparie une prévision à la série qui l'a honorée. Idempotent, et sans
   * effet sur une prévision déjà honorée : le premier appariement gagne, un
   * rejeu ne le déplace jamais.
   */
  async linkPlanItem(sessionId: string, planItemId: string, setId: string): Promise<void> {
    await this.prisma.workoutSessionPlanItem.updateMany({
      where: { id: planItemId, sessionId, doneSetId: null },
      data: { doneSetId: setId },
    });
  }

  /**
   * Passe des prévisions. Idempotent, et sans effet sur celles déjà honorées :
   * une série réalisée est un fait acquis, on ne la « saute » pas après coup.
   */
  async skipPlanItems(sessionId: string, planItemIds: string[]): Promise<number> {
    const updated = await this.prisma.workoutSessionPlanItem.updateMany({
      where: { id: { in: planItemIds }, sessionId, doneSetId: null },
      data: { skipped: true },
    });
    return updated.count;
  }

  findSessionById(id: string): Promise<SessionWithSets | null> {
    return this.prisma.workoutSession.findFirst({
      where: { id, deletedAt: null },
      include: ACTIVE_SETS,
    });
  }

  listSessionsPage(userId: string, limit: number, cursor?: string): Promise<SessionSummaryRow[]> {
    return this.prisma.workoutSession.findMany({
      where: { userId, deletedAt: null },
      include: SUMMARY_SETS,
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

  /**
   * Pierre tombale ET libération du plan, en une transaction : la série
   * supprimée rend sa prévision. Sans quoi l'item gardait un `doneSetId`
   * orphelin — compté « fait » pour toujours, jamais reproposé, et
   * `linkPlanItem` (qui exige `doneSetId` null) ne pouvait plus jamais le
   * réapparier ; la reprise multi-appareil rapatriait le même orphelin.
   */
  softDeleteSet(id: string): Promise<void> {
    return this.prisma
      .$transaction([
        this.prisma.workoutSet.update({ where: { id }, data: { deletedAt: new Date() } }),
        this.prisma.workoutSessionPlanItem.updateMany({
          where: { doneSetId: id },
          data: { doneSetId: null },
        }),
      ])
      .then(() => undefined);
  }

  async exercisePublishedName(exerciseId: string): Promise<string | null> {
    const names = await this.publishedExerciseNames([exerciseId]);
    return names.get(exerciseId) ?? null;
  }

  /** Noms du catalogue pour les identifiants PUBLIÉS ; les autres sont absents. */
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
}
