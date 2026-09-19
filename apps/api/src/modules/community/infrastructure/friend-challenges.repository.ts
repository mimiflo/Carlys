import { Injectable } from '@nestjs/common';
import {
  type ChallengeMetric,
  type FriendChallenge,
  type FriendChallengeMember,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

/** Un défi, ses membres, et le nom d'affichage de chacun. */
export type FriendChallengeWithMembers = FriendChallenge & {
  members: Array<FriendChallengeMember & { user: { profile: { displayName: string } | null } }>;
  creator: { profile: { displayName: string } | null };
};

const AVEC_MEMBRES = {
  members: {
    include: { user: { select: { profile: { select: { displayName: true } } } } },
    orderBy: [{ contribution: 'desc' }, { userId: 'asc' }],
  },
  creator: { select: { profile: { select: { displayName: true } } } },
} satisfies Prisma.FriendChallengeInclude;

/** Accès Prisma des défis entre amis — et de lui seul. */
@Injectable()
export class FriendChallengesRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Crée le défi ET ses membres dans UNE transaction.
   *
   * Rend `false` si l'identifiant existait déjà : c'est un REJEU, pas une
   * erreur — l'identifiant vient de l'appareil, et une création rejouée
   * après une coupure doit retrouver le défi, pas en poser un second.
   */
  async create(
    challenge: Prisma.FriendChallengeUncheckedCreateInput,
    invitedUserIds: string[],
  ): Promise<boolean> {
    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.friendChallenge.create({ data: challenge });
        await tx.friendChallengeMember.createMany({
          data: [
            // Le créateur est membre ACCEPTÉ d'office : il n'a pas à
            // s'inviter lui-même, et un défi sans lui n'aurait aucun sens.
            {
              challengeId: challenge.id,
              userId: challenge.creatorId,
              invitedById: challenge.creatorId,
              status: 'ACCEPTED',
              joinedAt: new Date(),
            },
            ...invitedUserIds.map((userId) => ({
              challengeId: challenge.id,
              userId,
              invitedById: challenge.creatorId,
            })),
          ],
        });
      });
      return true;
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        return false;
      }
      throw error;
    }
  }

  findById(id: string): Promise<FriendChallengeWithMembers | null> {
    return this.prisma.friendChallenge.findUnique({
      where: { id },
      include: AVEC_MEMBRES,
    });
  }

  /**
   * Les défis où l'appelant est membre à un titre ou à un autre — invité
   * compris, puisque c'est là qu'il voit ce qu'on lui propose.
   *
   * Les refusés et les quittés en sortent : ce sont des décisions prises,
   * pas des choses à revoir.
   */
  listMine(userId: string, limit: number): Promise<FriendChallengeWithMembers[]> {
    return this.prisma.friendChallenge.findMany({
      where: { members: { some: { userId, status: { in: ['INVITED', 'ACCEPTED'] } } } },
      include: AVEC_MEMBRES,
      orderBy: [{ endsAt: 'asc' }, { id: 'asc' }],
      take: limit,
    });
  }

  /** Défis OUVERTS déjà créés par cette personne — sert le plafond. */
  countOpenCreatedBy(userId: string, now: Date): Promise<number> {
    return this.prisma.friendChallenge.count({
      where: { creatorId: userId, status: 'OPEN', endsAt: { gte: now } },
    });
  }

  /** Change l'état d'un membre. Rend `false` si la ligne n'existe pas. */
  async setMemberStatus(
    challengeId: string,
    userId: string,
    status: FriendChallengeMember['status'],
    dates: { joinedAt?: Date | null; leftAt?: Date | null } = {},
  ): Promise<boolean> {
    const result = await this.prisma.friendChallengeMember.updateMany({
      where: { challengeId, userId },
      data: { status, ...dates },
    });
    return result.count > 0;
  }

  /**
   * `amount` sur tous les défis entre amis ACCEPTÉS, ouverts, de cette
   * métrique, dont la fenêtre couvre `at`.
   *
   * Même forme que la contribution collective, et c'est voulu : un seul
   * chemin d'écriture pour les deux familles de défis, sinon les deux
   * compteurs dérivent.
   */
  async contribute(
    userId: string,
    metric: ChallengeMetric,
    amount: number,
    at: Date,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<void> {
    if (amount <= 0) {
      return;
    }
    await client.friendChallengeMember.updateMany({
      where: {
        userId,
        status: 'ACCEPTED',
        challenge: { metric, status: 'OPEN', startsAt: { lte: at }, endsAt: { gte: at } },
      },
      data: { contribution: { increment: amount } },
    });
  }

  /**
   * RÈGLE un défi échu : fige les rangs, ferme le défi. Idempotent.
   *
   * L'écriture est conditionnée à `closedAt: null`, et c'est toute
   * l'idempotence : deux lectures simultanées d'un défi échu tentent chacune
   * le règlement, une seule le gagne. Sans cron — comme le jeu du mois, qui
   * se matérialise à la première lecture — mais avec une écriture, parce
   * qu'un classement doit rester stable même si plus personne ne regarde.
   */
  async settle(challengeId: string, ranks: Array<{ userId: string; rank: number }>): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const ferme = await tx.friendChallenge.updateMany({
        where: { id: challengeId, closedAt: null },
        data: { status: 'CLOSED', closedAt: new Date() },
      });
      if (ferme.count === 0) {
        return; // Déjà réglé par une lecture concurrente.
      }
      for (const { userId, rank } of ranks) {
        await tx.friendChallengeMember.updateMany({
          where: { challengeId, userId },
          data: { finalRank: rank },
        });
      }
    });
  }
}
