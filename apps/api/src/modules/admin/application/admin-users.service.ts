import {
  ENTITLEMENT_KEYS,
  type EntitlementKey,
  type ManagedUserDetail,
  type ManagedUserSummary,
} from '@carlys/api-contracts';
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { UserStatus } from '@prisma/client';
import { AuditService } from '../../audit/audit.service';
import { AdminRepository, type ManagedUserRow } from '../infrastructure/admin.repository';

export interface UsersPage {
  items: ManagedUserSummary[];
  nextCursor: string | null;
  hasMore: boolean;
}

function isPremiumNow(row: ManagedUserRow): boolean {
  const now = Date.now();
  return row.entitlements.some(
    (entitlement) =>
      entitlement.entitlementKey === 'premium_exercises' &&
      entitlement.isActive &&
      (entitlement.expiresAt === null || entitlement.expiresAt.getTime() > now),
  );
}

function presentSummary(row: ManagedUserRow): ManagedUserSummary {
  return {
    id: row.id,
    email: row.email,
    displayName: row.profile?.displayName ?? null,
    status: row.status,
    emailVerified: row.emailVerifiedAt !== null,
    isPremium: isPremiumNow(row),
    createdAt: row.createdAt.toISOString(),
  };
}

/** Gestion des comptes mobiles depuis le back-office — tout est AUDITÉ. */
@Injectable()
export class AdminUsersService {
  constructor(
    private readonly admin: AdminRepository,
    private readonly audit: AuditService,
  ) {}

  async listUsers(search: string | undefined, limit: number, cursor?: string): Promise<UsersPage> {
    const rows = await this.admin.listUsers(search, limit, cursor);
    const hasMore = rows.length > limit;
    const items = rows.slice(0, limit).map(presentSummary);
    return {
      items,
      hasMore,
      nextCursor: hasMore ? (items.at(-1)?.id ?? null) : null,
    };
  }

  async userDetail(userId: string): Promise<ManagedUserDetail> {
    const row = await this.ownedUser(userId);
    const activity = await this.admin.userActivity(userId);
    const now = Date.now();
    const byKey = new Map(row.entitlements.map((row) => [row.entitlementKey, row]));

    return {
      ...presentSummary(row),
      sessionsCount: activity.sessionsCount,
      completedWorkoutsCount: activity.completedCount,
      entitlements: ENTITLEMENT_KEYS.map((key) => {
        const entitlement = byKey.get(key);
        return {
          key,
          isActive:
            entitlement !== undefined &&
            entitlement.isActive &&
            (entitlement.expiresAt === null || entitlement.expiresAt.getTime() > now),
          expiresAt: entitlement?.expiresAt?.toISOString() ?? null,
        };
      }),
    };
  }

  /**
   * Suspension/réactivation. La suspension révoque TOUTES les sessions
   * actives : les jetons émis meurent immédiatement.
   */
  async setUserStatus(
    userId: string,
    status: 'ACTIVE' | 'SUSPENDED',
    actor: { adminUserId: string; ipAddress?: string; requestId?: string },
  ): Promise<ManagedUserSummary> {
    const user = await this.ownedUser(userId);
    if (user.status === UserStatus.DELETED) {
      throw new ConflictException('Compte supprimé — statut non modifiable.');
    }

    if (user.status !== status) {
      await this.admin.setUserStatus(userId, status);
      let revoked = 0;
      if (status === 'SUSPENDED') {
        revoked = await this.admin.revokeUserSessions(userId, 'admin_suspension');
      }
      this.audit.record({
        action: status === 'SUSPENDED' ? 'admin.user_suspended' : 'admin.user_reactivated',
        actorType: 'ADMIN',
        adminUserId: actor.adminUserId,
        userId,
        resourceType: 'user',
        resourceId: userId,
        requestId: actor.requestId,
        ipAddress: actor.ipAddress,
        metadata: { revokedSessions: revoked },
      });
    }

    const updated = await this.ownedUser(userId);
    return presentSummary(updated);
  }

  /** Attribution/retrait MANUEL d'un droit — tracé, jamais écrasé par la synchro. */
  async setEntitlement(
    userId: string,
    key: EntitlementKey,
    input: { isActive: boolean; expiresAt: Date | null },
    actor: { adminUserId: string; ipAddress?: string; requestId?: string },
  ): Promise<ManagedUserDetail> {
    await this.ownedUser(userId);
    await this.admin.upsertManualEntitlement(userId, key, input);
    this.audit.record({
      action: input.isActive ? 'admin.entitlement_granted' : 'admin.entitlement_revoked',
      actorType: 'ADMIN',
      adminUserId: actor.adminUserId,
      userId,
      resourceType: 'entitlement',
      resourceId: `${userId}:${key}`,
      requestId: actor.requestId,
      ipAddress: actor.ipAddress,
      metadata: { key, expiresAt: input.expiresAt?.toISOString() ?? null },
    });
    return this.userDetail(userId);
  }

  private async ownedUser(userId: string): Promise<ManagedUserRow> {
    const row = await this.admin.findUserById(userId);
    if (row === null) {
      throw new NotFoundException('Utilisateur introuvable.');
    }
    return row;
  }
}
