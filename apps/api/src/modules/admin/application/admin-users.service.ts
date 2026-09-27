import {
  type EntitlementKey,
  type ManagedUserDetail,
  type ManagedUserSummary,
} from '@carlys/api-contracts';
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { UserStatus } from '@prisma/client';
import { AuditService } from '../../audit/audit.service';
import {
  EntitlementsService,
  rowIsActive,
} from '../../subscriptions/application/entitlements.service';
import {
  AdminUsersRepository,
  type ManagedUserDetailRow,
  type ManagedUserRow,
} from '../infrastructure/admin-users.repository';
import {
  entitlementSource,
  paidSubscriptionOf,
  presentManagedEntitlements,
} from './managed-entitlements';

interface AdminActor {
  adminUserId: string;
  ipAddress?: string;
  requestId?: string;
}

export interface UsersPage {
  items: ManagedUserSummary[];
  nextCursor: string | null;
  hasMore: boolean;
}

function isPremiumNow(row: ManagedUserRow): boolean {
  const now = Date.now();
  return row.entitlements.some(
    (entitlement) =>
      entitlement.entitlementKey === 'premium_exercises' && rowIsActive(entitlement, now),
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
    private readonly admin: AdminUsersRepository,
    private readonly audit: AuditService,
    private readonly entitlements: EntitlementsService,
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
    const [activity, subscriptions] = await Promise.all([
      this.admin.userActivity(userId),
      this.admin.listSubscriptions(userId),
    ]);
    const now = Date.now();

    return {
      ...presentSummary(row),
      sessionsCount: activity.sessionsCount,
      completedWorkoutsCount: activity.completedCount,
      entitlements: presentManagedEntitlements(row.entitlements, now),
      paidSubscription: paidSubscriptionOf(subscriptions, now),
    };
  }

  /**
   * Suspension/réactivation. La suspension révoque TOUTES les sessions
   * actives : les jetons émis meurent immédiatement.
   */
  async setUserStatus(
    userId: string,
    status: 'ACTIVE' | 'SUSPENDED',
    actor: AdminActor,
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

  /**
   * Attribution/retrait MANUEL d'un droit — tracé, jamais écrasé par la
   * synchro. Un retrait COUPE aussi un accès payé et bloque les achats :
   * la raison donnée par l'administration part dans l'audit.
   */
  async setEntitlement(
    userId: string,
    key: EntitlementKey,
    input: { isActive: boolean; expiresAt: Date | null; reason?: string },
    actor: AdminActor,
  ): Promise<ManagedUserDetail> {
    await this.ownedUser(userId);
    await this.admin.upsertManualEntitlement(userId, key, {
      isActive: input.isActive,
      expiresAt: input.expiresAt,
    });
    this.audit.record({
      action: input.isActive ? 'admin.entitlement_granted' : 'admin.entitlement_revoked',
      actorType: 'ADMIN',
      adminUserId: actor.adminUserId,
      userId,
      resourceType: 'entitlement',
      resourceId: `${userId}:${key}`,
      requestId: actor.requestId,
      ipAddress: actor.ipAddress,
      metadata: {
        key,
        expiresAt: input.expiresAt?.toISOString() ?? null,
        reason: input.reason ?? null,
      },
    });
    return this.userDetail(userId);
  }

  /**
   * Rend la main à l'abonnement : la décision manuelle (octroi OU coupure)
   * disparaît, puis les droits se recalculent depuis les abonnements du
   * compte. Un membre qui paie retrouve son accès ; sans abonnement, le droit
   * redevient simplement absent. Idempotent : sans décision manuelle, rien
   * ne change, et le geste est tout de même tracé.
   */
  async releaseEntitlement(
    userId: string,
    key: EntitlementKey,
    actor: AdminActor,
  ): Promise<ManagedUserDetail> {
    const user = await this.ownedUser(userId);
    const previous = entitlementSource(user.entitlements.find((row) => row.entitlementKey === key));
    const removed = await this.admin.deleteManualEntitlement(userId, key);
    await this.entitlements.resyncFromSubscriptions(userId);
    this.audit.record({
      action: 'admin.entitlement_released',
      actorType: 'ADMIN',
      adminUserId: actor.adminUserId,
      userId,
      resourceType: 'entitlement',
      resourceId: `${userId}:${key}`,
      requestId: actor.requestId,
      ipAddress: actor.ipAddress,
      metadata: { key, previousSource: previous, removed: removed > 0 },
    });
    return this.userDetail(userId);
  }

  private async ownedUser(userId: string): Promise<ManagedUserDetailRow> {
    const row = await this.admin.findUserById(userId);
    if (row === null) {
      throw new NotFoundException('Utilisateur introuvable.');
    }
    return row;
  }
}
