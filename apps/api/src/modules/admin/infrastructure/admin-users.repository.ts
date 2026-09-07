import { Injectable } from '@nestjs/common';
import { type Prisma, UserStatus, WorkoutSessionStatus } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export type ManagedUserRow = Prisma.UserGetPayload<{
  include: { profile: true; entitlements: true };
}>;

/** Les comptes MOBILES vus du back-office : lecture, statut, droits manuels. */
@Injectable()
export class AdminUsersRepository {
  constructor(private readonly prisma: PrismaService) {}

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

  findUserById(id: string): Promise<ManagedUserRow | null> {
    return this.prisma.user.findUnique({
      where: { id },
      include: { profile: true, entitlements: true },
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

  /** Révoque toutes les sessions actives : les access tokens meurent aussitôt. */
  revokeUserSessions(userId: string, reason: string): Promise<number> {
    return this.prisma.userSession
      .updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date(), revokedReason: reason },
      })
      .then((result) => result.count);
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
}
