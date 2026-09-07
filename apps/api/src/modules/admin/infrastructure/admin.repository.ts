import { Injectable } from '@nestjs/common';
import {
  type AdminUserStatus,
  type AuditLog,
  type Prisma,
  UserStatus,
  WorkoutSessionStatus,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export type AdminWithAccess = Prisma.AdminUserGetPayload<{
  include: {
    roles: { include: { role: { include: { permissions: { include: { permission: true } } } } } };
  };
}>;

export interface OverviewCounts {
  usersCount: number;
  premiumUsersCount: number;
  workoutSessionsCount: number;
  completedWorkoutSessionsCount: number;
  exercisesCount: number;
  publishedExercisesCount: number;
}

/**
 * Les COMPTES D'ADMINISTRATION eux-mêmes (séparés des comptes mobiles), plus
 * le journal d'audit et la synthèse de la plateforme.
 *
 * Les utilisateurs gérés et le catalogue ont leur propre dépôt
 * ([AdminUsersRepository], [AdminCatalogRepository]) : ce sont trois sujets,
 * trois services, et rien ne circule de l'un à l'autre.
 */
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
      this.prisma.exercise.count({ where: { deletedAt: null } }),
      this.prisma.exercise.count({ where: { isPublished: true, deletedAt: null } }),
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
