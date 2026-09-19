import { Injectable } from '@nestjs/common';
import { type LeagueDivision, type LeagueMembership, Prisma } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

/** Une ligne de classement, avec le nom qu'on affiche à côté du score. */
export type LeagueMemberWithName = LeagueMembership & {
  user: { profile: { displayName: string } | null };
};

/** Accès Prisma des ligues — et de lui seul. */
@Injectable()
export class LeaguesRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Vrai si cette personne a rejoint la ligue. Absence de ligne = non. */
  async hasJoined(
    userId: string,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<boolean> {
    const preference = await client.communityPreference.findUnique({
      where: { userId },
      select: { joinsLeague: true },
    });
    return preference?.joinsLeague ?? false;
  }

  /** Entre dans la ligue, ou en sort. Crée la préférence si besoin. */
  async setJoined(userId: string, joined: boolean): Promise<void> {
    await this.prisma.communityPreference.upsert({
      where: { userId },
      create: { userId, joinsLeague: joined },
      update: { joinsLeague: joined },
    });
  }

  membership(userId: string, periodKey: string): Promise<LeagueMembership | null> {
    return this.prisma.leagueMembership.findUnique({
      where: { userId_periodKey: { userId, periodKey } },
    });
  }

  /**
   * La division à ouvrir pour une nouvelle période : celle que le dernier
   * règlement a décidée, à défaut celle de la dernière période connue, et
   * BRONZE si c'est la première.
   *
   * On lit la dernière période quelle qu'elle soit : six semaines d'absence
   * ne créent aucune ligne, donc la dernière connue EST la division quittée.
   * C'est la conséquence de la matérialisation paresseuse, pas une règle
   * ajoutée par-dessus.
   */
  async divisionToOpen(
    userId: string,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<LeagueDivision> {
    const derniere = await client.leagueMembership.findFirst({
      where: { userId },
      orderBy: { periodKey: 'desc' },
      select: { division: true, nextDivision: true },
    });
    return derniere?.nextDivision ?? derniere?.division ?? 'BRONZE';
  }

  /**
   * Ouvre la période si elle n'existe pas, et rend la ligne.
   *
   * `create` en attrapant P2002 plutôt qu'un `upsert` vide : deux écritures
   * simultanées sur la même période sont normales (une contribution et une
   * lecture), et l'unicité `(userId, periodKey)` les absorbe.
   */
  async openPeriod(
    userId: string,
    periodKey: string,
    division: LeagueDivision,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<void> {
    try {
      await client.leagueMembership.create({ data: { userId, periodKey, division } });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return; // Ouverte entre-temps par une écriture concurrente.
      }
      throw error;
    }
  }

  /**
   * Ajoute des points à la période, si la ligne existe ET n'est pas réglée.
   * Rend le nombre de lignes touchées — 0 veut dire « à ouvrir ».
   *
   * Jamais de création ici, et jamais d'écriture sur une période RÉGLÉE :
   * un effort qui arrive en retard (une séance synchronisée après coup) ne
   * doit pas faire bouger un classement déjà annoncé.
   */
  async addPoints(
    userId: string,
    periodKey: string,
    points: number,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<number> {
    if (points <= 0) {
      return 0;
    }
    const result = await client.leagueMembership.updateMany({
      where: { userId, periodKey, settledAt: null },
      data: { score: { increment: points } },
    });
    return result.count;
  }

  /** Le classement d'une division pour une période, du meilleur au dernier. */
  standings(periodKey: string, division: LeagueDivision): Promise<LeagueMemberWithName[]> {
    return this.prisma.leagueMembership.findMany({
      where: { periodKey, division },
      include: { user: { select: { profile: { select: { displayName: true } } } } },
      orderBy: [{ score: 'desc' }, { userId: 'asc' }],
    });
  }

  /** Les périodes passées de cette personne qui n'ont jamais été réglées. */
  unsettledBefore(userId: string, periodKey: string): Promise<LeagueMembership[]> {
    return this.prisma.leagueMembership.findMany({
      where: { userId, settledAt: null, periodKey: { lt: periodKey } },
      orderBy: { periodKey: 'asc' },
    });
  }

  /**
   * RÈGLE une division entière pour une période close : rangs figés,
   * division suivante décidée, `settledAt` posé. Idempotent.
   *
   * L'écriture est conditionnée à `settledAt: null` — deux lectures
   * simultanées d'une période échue n'en règlent qu'une. Et c'est une
   * lecture, quelle qu'elle soit, qui règle la division ENTIÈRE : sans ça,
   * deux personnes liraient deux classements différents de la même semaine.
   *
   * Le règlement n'OUVRE rien : la période suivante naît quand quelqu'un la
   * lit ou y verse un effort. Ouvrir ici créerait une ligne par semaine
   * d'absence, et chaque lecture d'un revenant en déclencherait la cascade.
   */
  async settle(
    periodKey: string,
    results: ReadonlyArray<{ userId: string; rank: number; nextDivision: LeagueDivision }>,
  ): Promise<number> {
    return this.prisma.$transaction(async (tx) => {
      const regle = await tx.leagueMembership.updateMany({
        where: { periodKey, settledAt: null, userId: { in: results.map((r) => r.userId) } },
        data: { settledAt: new Date() },
      });
      if (regle.count === 0) {
        return 0; // Déjà réglée par une lecture concurrente.
      }
      for (const { userId, rank, nextDivision } of results) {
        await tx.leagueMembership.updateMany({
          where: { userId, periodKey },
          data: { finalRank: rank, nextDivision },
        });
      }
      return regle.count;
    });
  }
}
