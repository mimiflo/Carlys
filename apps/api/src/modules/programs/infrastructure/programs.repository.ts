import { Injectable } from '@nestjs/common';
import { type Prisma, type ProgramDay } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export type ProgramWithDays = Prisma.ProgramGetPayload<{
  include: { days: true };
}>;

/**
 * Ce qu'une LIGNE DE LISTE lit d'un programme : le nombre de jours, pas les
 * jours.
 *
 * La liste partageait l'include du détail. Elle rapatriait donc, pour chaque
 * programme d'une page, la totalité de ses jours — jusqu'à 364 lignes par
 * programme, triées par PostgreSQL — pour n'en garder qu'un `length`. Même
 * défaut, même remède que l'historique des séances (`SUMMARY_SETS`).
 */
export type ProgramSummaryRow = Prisma.ProgramGetPayload<{
  include: { _count: { select: { days: true } } };
}>;

/** Accès Prisma des programmes — et de lui seul. */
@Injectable()
export class ProgramsRepository {
  constructor(private readonly prisma: PrismaService) {}

  listPage(userId: string, limit: number, cursor?: string): Promise<ProgramSummaryRow[]> {
    return this.prisma.program.findMany({
      where: { userId, deletedAt: null },
      include: { _count: { select: { days: true } } },
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursor === undefined ? {} : { cursor: { id: cursor }, skip: 1 }),
    });
  }

  findById(id: string): Promise<ProgramWithDays | null> {
    return this.prisma.program.findUnique({
      where: { id },
      include: { days: { orderBy: [{ weekNumber: 'asc' }, { dayOfWeek: 'asc' }] } },
    });
  }

  /**
   * Les jours d'UNE SEULE semaine, avec la séance terminée qui honore
   * chacun.
   *
   * Deux requêtes, jamais huit : `findById` charge TOUS les jours du
   * programme — jusqu'à 364 — et une lecture par case rouvrirait le N+1 déjà
   * corrigé sur ce module.
   */
  async weekWithSessions(
    programId: string,
    userId: string,
    weekNumber: number,
  ): Promise<{ days: ProgramDay[]; doneByDayId: Map<string, string> }> {
    const days = await this.prisma.programDay.findMany({
      where: { programId, weekNumber },
      orderBy: { dayOfWeek: 'asc' },
    });
    if (days.length === 0) {
      return { days, doneByDayId: new Map() };
    }
    const sessions = await this.prisma.workoutSession.findMany({
      where: {
        userId,
        programDayId: { in: days.map((day) => day.id) },
        status: 'COMPLETED',
        // La suppression est LOGIQUE : sans ce filtre, une case brillerait
        // encore pour une séance que la personne a effacée.
        deletedAt: null,
      },
      select: { id: true, programDayId: true },
      orderBy: { startedAt: 'asc' },
    });
    const doneByDayId = new Map<string, string>();
    for (const session of sessions) {
      if (session.programDayId !== null) {
        doneByDayId.set(session.programDayId, session.id);
      }
    }
    return { days, doneByDayId };
  }

  /**
   * Le fuseau déclaré par la personne, tel qu'il est en base.
   *
   * Lu ICI plutôt qu'emprunté à `progress` : deux modules métier n'ont pas à
   * se connaître pour six lignes de lecture, et `safeTimeZone` — le seul
   * endroit où se décide ce qu'on fait d'une valeur douteuse — reste
   * partagé.
   */
  async userTimeZone(userId: string): Promise<string | null> {
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId },
      select: { timezone: true },
    });
    return profile?.timezone ?? null;
  }

  /** Le jour de programme `id`, s'il appartient à un programme vivant de `userId`. */
  async findOwnedDay(id: string, userId: string): Promise<ProgramDay | null> {
    return this.prisma.programDay.findFirst({
      where: { id, program: { userId, deletedAt: null } },
    });
  }

  /**
   * La séance TERMINÉE `id` de `userId`, si elle existe et vit encore.
   *
   * `startedAt` suffit à l'appelant : c'est l'instant qui décide de quel
   * JOUR CIVIL la séance relève, et donc quelle case elle peut honorer.
   */
  findOwnedCompletedSession(
    id: string,
    userId: string,
  ): Promise<{ id: string; startedAt: Date } | null> {
    return this.prisma.workoutSession.findFirst({
      where: { id, userId, status: 'COMPLETED', deletedAt: null },
      select: { id: true, startedAt: true },
    });
  }

  /**
   * Fait reconnaître `sessionId` par la case `dayId` — ou n'en fait plus
   * reconnaître aucune quand il vaut `null`.
   *
   * EXCLUSIF, et en une transaction : toute autre séance qui pointait sur
   * cette case est déliée d'abord. Sans cette exclusivité, deux séances
   * pourraient honorer la même case, la lecture n'en montrerait qu'une (la
   * plus ancienne), et « délier » ne saurait plus laquelle viser.
   *
   * Le cas où `sessionId` pointait déjà sur une AUTRE case se règle tout
   * seul : `programDayId` est une colonne unique par séance, donc l'écrire
   * la détache de l'ancienne. Une séance honore au plus un jour, un jour est
   * honoré par au plus une séance.
   */
  async linkSessionToDay(dayId: string, userId: string, sessionId: string | null): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await tx.workoutSession.updateMany({
        where: {
          userId,
          programDayId: dayId,
          ...(sessionId === null ? {} : { id: { not: sessionId } }),
        },
        data: { programDayId: null },
      });
      if (sessionId !== null) {
        await tx.workoutSession.updateMany({
          where: { id: sessionId, userId },
          data: { programDayId: dayId },
        });
      }
    });
  }

  /** Programmes vivants d'un compte — sert le plafond du plan gratuit. */
  countLive(userId: string): Promise<number> {
    return this.prisma.program.count({ where: { userId, deletedAt: null } });
  }

  /** Modèles de ce compte parmi les identifiants reçus. */
  async ownedTemplateIds(userId: string, ids: string[]): Promise<Set<string>> {
    if (ids.length === 0) return new Set();
    const rows = await this.prisma.workoutTemplate.findMany({
      where: { id: { in: ids }, userId, deletedAt: null },
      select: { id: true },
    });
    return new Set(rows.map((row) => row.id));
  }

  /**
   * Écrit l'état complet du programme en UNE transaction.
   *
   * Le contenu est remplacé physiquement : ce n'est pas de l'historique, et
   * c'est ce qui rend le `PUT` rejouable sans journal d'idempotence.
   */
  async save(
    program: Prisma.ProgramUncheckedCreateInput,
    days: Prisma.ProgramDayCreateManyInput[],
    activate: boolean,
  ): Promise<ProgramWithDays> {
    return this.prisma.$transaction(async (tx) => {
      const { id, userId, ...rest } = program;
      await tx.program.upsert({
        where: { id },
        create: { id, userId, ...rest },
        update: { ...rest, deletedAt: null },
      });
      await tx.programDay.deleteMany({ where: { programId: id } });
      if (days.length > 0) {
        await tx.programDay.createMany({ data: days });
      }
      // Un seul programme « en cours » : les autres redescendent ici même,
      // dans la transaction — sinon deux programmes actifs coexisteraient le
      // temps d'un aller-retour, et l'accueil ne saurait lequel montrer.
      if (activate) {
        await tx.program.updateMany({
          where: { userId, id: { not: id }, isActive: true },
          data: { isActive: false },
        });
      }
      return tx.program.findUniqueOrThrow({
        where: { id },
        include: { days: { orderBy: [{ weekNumber: 'asc' }, { dayOfWeek: 'asc' }] } },
      });
    });
  }

  /** Suppression logique. Rend `false` si rien n'a changé. */
  async softDelete(id: string, userId: string): Promise<boolean> {
    const result = await this.prisma.program.updateMany({
      where: { id, userId, deletedAt: null },
      data: { deletedAt: new Date(), isActive: false },
    });
    return result.count > 0;
  }
}
