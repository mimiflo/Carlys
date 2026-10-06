import { Injectable } from '@nestjs/common';
import { type Prisma, UserStatus, WorkoutSessionStatus } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';
import { SessionCache } from '../../../infrastructure/cache/session-cache';

export type ManagedUserRow = Prisma.UserGetPayload<{
  include: { profile: true; entitlements: true };
}>;

/**
 * La fiche d'un compte : chaque droit porte le fournisseur de l'abonnement
 * qui l'a posé, pour que le back-office sache D'OÙ vient un accès avant d'y
 * toucher.
 */
const DETAIL_INCLUDE = {
  profile: true,
  entitlements: { include: { sourceSubscription: { select: { provider: true } } } },
} satisfies Prisma.UserInclude;

export type ManagedUserDetailRow = Prisma.UserGetPayload<{ include: typeof DETAIL_INCLUDE }>;

export type ManagedSubscriptionRow = Prisma.SubscriptionGetPayload<{
  select: {
    provider: true;
    status: true;
    currentPeriodEnd: true;
    cancelAtPeriodEnd: true;
  };
}>;

/** Les comptes MOBILES vus du back-office : lecture, statut, droits manuels. */
@Injectable()
export class AdminUsersRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sessionCache: SessionCache,
  ) {}

  listUsers(search: string | undefined, limit: number, cursor?: string): Promise<ManagedUserRow[]> {
    return this.prisma.user.findMany({
      where:
        search === undefined
          ? {}
          : {
              OR: [
                { email: { contains: search, mode: 'insensitive' } },
                { profile: { displayName: { contains: search, mode: 'insensitive' } } },
              ],
            },
      include: { profile: true, entitlements: true },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursor === undefined ? {} : { cursor: { id: cursor }, skip: 1 }),
    });
  }

  findUserById(id: string): Promise<ManagedUserDetailRow | null> {
    return this.prisma.user.findUnique({ where: { id }, include: DETAIL_INCLUDE });
  }

  /** Abonnements du compte, le plus récemment touché d'abord. */
  listSubscriptions(userId: string): Promise<ManagedSubscriptionRow[]> {
    return this.prisma.subscription.findMany({
      where: { userId },
      select: { provider: true, status: true, currentPeriodEnd: true, cancelAtPeriodEnd: true },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async userActivity(userId: string): Promise<{ sessionsCount: number; completedCount: number }> {
    const [sessionsCount, completedCount] = await Promise.all([
      this.prisma.userSession.count({ where: { userId, revokedAt: null } }),
      this.prisma.workoutSession.count({
        where: { userId, status: WorkoutSessionStatus.COMPLETED, deletedAt: null },
      }),
    ]);
    return { sessionsCount, completedCount };
  }

  setUserStatus(userId: string, status: UserStatus): Promise<void> {
    return this.prisma.user
      .update({ where: { id: userId }, data: { status } })
      .then(() => undefined);
  }

  /**
   * Révoque toutes les sessions actives : les access tokens meurent aussitôt,
   * et les jetons push du compte tombent avec elles — un compte suspendu ne
   * reçoit plus de notification.
   */
  async revokeUserSessions(userId: string, reason: string): Promise<number> {
    const [revoked] = await this.prisma.$transaction([
      this.prisma.userSession.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date(), revokedReason: reason },
      }),
      this.prisma.deviceToken.deleteMany({ where: { userId } }),
    ]);
    await this.sessionCache.forget(userId);
    return revoked.count;
  }

  /** Attribution MANUELLE : sourceSubscriptionId null, jamais écrasée par la synchro. */
  upsertManualEntitlement(
    userId: string,
    entitlementKey: string,
    data: { isActive: boolean; expiresAt: Date | null },
  ): Promise<void> {
    return this.prisma.userEntitlement
      .upsert({
        where: { userId_entitlementKey: { userId, entitlementKey } },
        create: { userId, entitlementKey, ...data, sourceSubscriptionId: null },
        update: { ...data, sourceSubscriptionId: null },
      })
      .then(() => undefined);
  }

  /**
   * Retire la décision MANUELLE posée sur un droit (octroi comme coupure).
   * Une ligne posée par un abonnement n'est jamais visée : elle se
   * recalcule, elle ne s'efface pas. Rend le nombre de lignes retirées.
   */
  deleteManualEntitlement(userId: string, entitlementKey: string): Promise<number> {
    return this.prisma.userEntitlement
      .deleteMany({ where: { userId, entitlementKey, sourceSubscriptionId: null } })
      .then((result) => result.count);
  }
}
