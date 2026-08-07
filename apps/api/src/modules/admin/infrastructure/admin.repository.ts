import { Injectable } from '@nestjs/common';
import {
  type AdminUserStatus,
  type AuditLog,
  Prisma,
  UserStatus,
  WorkoutSessionStatus,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export type AdminWithAccess = Prisma.AdminUserGetPayload<{
  include: {
    roles: { include: { role: { include: { permissions: { include: { permission: true } } } } } };
  };
}>;

export type ManagedUserRow = Prisma.UserGetPayload<{
  include: { profile: true; entitlements: true };
}>;

export interface OverviewCounts {
  usersCount: number;
  premiumUsersCount: number;
  workoutSessionsCount: number;
  completedWorkoutSessionsCount: number;
  exercisesCount: number;
  publishedExercisesCount: number;
}

@Injectable()
export class AdminRepository {
  constructor(private readonly prisma: PrismaService) {}

  // ── Comptes d'administration ────────────────────────────────────────────

  findAdminByEmail(email: string): Promise<AdminWithAccess | null> {
    return this.prisma.adminUser.findUnique({
      where: { email },
      include: this.accessInclude(),
    });
  }

  findAdminById(id: string): Promise<AdminWithAccess | null> {
    return this.prisma.adminUser.findUnique({
      where: { id },
      include: this.accessInclude(),
    });
  }

  markLogin(adminUserId: string): Promise<void> {
    return this.prisma.adminUser
      .update({ where: { id: adminUserId }, data: { lastLoginAt: new Date() } })
      .then(() => undefined);
  }

  // ── Utilisateurs gérés ──────────────────────────────────────────────────

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

  // ── Catalogue ───────────────────────────────────────────────────────────

  setExercisePublication(exerciseId: string, isPublished: boolean): Promise<boolean> {
    return this.prisma.exercise
      .updateMany({ where: { id: exerciseId }, data: { isPublished } })
      .then((result) => result.count > 0);
  }

  // ── Audit & synthèse ────────────────────────────────────────────────────

  listAuditLogs(limit: number, cursor?: string): Promise<AuditLog[]> {
    return this.prisma.auditLog.findMany({
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursor === undefined ? {} : { cursor: { id: cursor }, skip: 1 }),
    });
  }

  async overview(): Promise<OverviewCounts> {
    const now = new Date();
    const [
      usersCount,
      premiumUsersCount,
      workoutSessionsCount,
      completedWorkoutSessionsCount,
      exercisesCount,
      publishedExercisesCount,
    ] = await Promise.all([
      this.prisma.user.count({ where: { status: { not: UserStatus.DELETED } } }),
      this.prisma.userEntitlement.count({
        where: {
          entitlementKey: 'premium_exercises',
          isActive: true,
          OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
        },
      }),
      this.prisma.workoutSession.count({ where: { deletedAt: null } }),
      this.prisma.workoutSession.count({
        where: { status: WorkoutSessionStatus.COMPLETED, deletedAt: null },
      }),
      this.prisma.exercise.count(),
      this.prisma.exercise.count({ where: { isPublished: true } }),
    ]);
    return {
      usersCount,
      premiumUsersCount,
      workoutSessionsCount,
      completedWorkoutSessionsCount,
      exercisesCount,
      publishedExercisesCount,
    };
  }

  private accessInclude() {
    return {
      roles: {
        include: {
          role: { include: { permissions: { include: { permission: true } } } },
        },
      },
    } as const;
  }
}

export function permissionsOf(admin: AdminWithAccess): string[] {
  const permissions = new Set<string>();
  for (const link of admin.roles) {
    for (const rolePermission of link.role.permissions) {
      permissions.add(`${rolePermission.permission.resource}:${rolePermission.permission.action}`);
    }
  }
  return [...permissions].sort();
}

export function rolesOf(admin: AdminWithAccess): string[] {
  return admin.roles.map((link) => link.role.slug).sort();
}

export type { AdminUserStatus };
