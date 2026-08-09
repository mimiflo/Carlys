import { Injectable } from '@nestjs/common';
import { type Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export type ProgramWithDays = Prisma.ProgramGetPayload<{
  include: { days: true };
}>;

/** Accès Prisma des programmes — et de lui seul. */
@Injectable()
export class ProgramsRepository {
  constructor(private readonly prisma: PrismaService) {}

  listPage(userId: string, limit: number, cursor?: string): Promise<ProgramWithDays[]> {
    return this.prisma.program.findMany({
      where: { userId, deletedAt: null },
      include: { days: { orderBy: [{ weekNumber: 'asc' }, { dayOfWeek: 'asc' }] } },
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
