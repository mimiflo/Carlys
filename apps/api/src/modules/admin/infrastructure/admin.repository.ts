import { Injectable } from '@nestjs/common';
import { type AuditLog, type Prisma, UserStatus, WorkoutSessionStatus } from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

/**
 * Codes faux d'affilée avant que la double authentification ne se gèle :
 * 20 essais sur un million de codes (trois admis par fenêtre) laissent
 * moins d'une chance sur 15 000 à qui devine.
 */
export const TOTP_MAX_FAILED_ATTEMPTS = 20;

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

  /**
   * RÉSERVE un essai de code, AVANT de le vérifier : `false` une fois
   * [TOTP_MAX_FAILED_ATTEMPTS] essais ratés d'affilée — la double
   * authentification est alors gelée jusqu'à `--reset-2fa`. En base, donc
   * sans dépendre de Redis ; conditionnel, donc atomique sous une rafale.
   */
  reserveTotpAttempt(adminUserId: string): Promise<boolean> {
    return this.prisma.adminUser
      .updateMany({
        where: { id: adminUserId, totpFailedAttempts: { lt: TOTP_MAX_FAILED_ATTEMPTS } },
        data: { totpFailedAttempts: { increment: 1 } },
      })
      .then(({ count }) => count === 1);
  }

  /**
   * Consomme un pas de 30 s accepté, remet les essais à zéro — et confirme
   * l'enrôlement s'il était en attente. Conditionnel : deux requêtes
   * simultanées avec le même code ne passent pas toutes les deux, et un
   * secret remplacé entre-temps (`--reset-2fa`) ne s'active pas (`false`).
   */
  claimTotpStep(
    adminUserId: string,
    sealedSecret: string,
    step: number,
    enabledAt: Date,
  ): Promise<boolean> {
    return this.prisma.adminUser
      .updateMany({
        where: {
          id: adminUserId,
          totpSecret: sealedSecret,
          OR: [{ totpLastStep: null }, { totpLastStep: { lt: step } }],
        },
        data: { totpLastStep: step, totpEnabledAt: enabledAt, totpFailedAttempts: 0 },
      })
      .then(({ count }) => count === 1);
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
