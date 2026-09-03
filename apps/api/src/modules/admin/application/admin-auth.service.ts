import { type AdminLoginResult, type AdminMe, adminPermissionSchema } from '@carlys/api-contracts';
import { HttpException, HttpStatus, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AdminUserStatus } from '@prisma/client';
import { AuditService } from '../../audit/audit.service';
import { LockoutService, lockoutMessage } from '../../auth/application/lockout.service';
import { PasswordService } from '../../auth/application/password.service';
import { AppConfigService } from '../../../config/app-config.service';
import {
  AdminRepository,
  type AdminWithAccess,
  permissionsOf,
  rolesOf,
} from '../infrastructure/admin.repository';

/** Audience JWT dédiée : un jeton admin n'est JAMAIS accepté côté mobile (et inversement). */
export const ADMIN_JWT_AUDIENCE = 'carlys-admin';
/** Durée de vie du jeton admin — pas de refresh : reconnexion quotidienne. */
export const ADMIN_TOKEN_TTL_SECONDS = 12 * 3_600;

const INVALID_CREDENTIALS_MESSAGE = 'E-mail ou mot de passe incorrect.';

/**
 * Compteur de verrouillage propre au back-office : même politique que le
 * mobile (LockoutService), mais un compte admin et un compte mobile de même
 * adresse ne partagent jamais leurs échecs.
 */
export function adminLockoutIdentifier(email: string): string {
  return `admin:${email}`;
}

export function presentAdmin(admin: AdminWithAccess): AdminMe {
  return {
    id: admin.id,
    email: admin.email,
    displayName: admin.displayName,
    roles: rolesOf(admin),
    permissions: permissionsOf(admin).flatMap((permission) => {
      const parsed = adminPermissionSchema.safeParse(permission);
      return parsed.success ? [parsed.data] : [];
    }),
  };
}

@Injectable()
export class AdminAuthService {
  constructor(
    private readonly admins: AdminRepository,
    private readonly passwords: PasswordService,
    private readonly jwt: JwtService,
    private readonly config: AppConfigService,
    private readonly audit: AuditService,
    private readonly lockout: LockoutService,
  ) {}

  async login(
    input: { email: string; password: string },
    client: { ipAddress?: string; userAgent?: string },
  ): Promise<AdminLoginResult> {
    const email = input.email.trim().toLowerCase();
    const lockoutId = adminLockoutIdentifier(email);

    // Verrouillé : refus AVANT toute lecture du compte, sans révéler s'il existe.
    const lock = await this.lockout.status(lockoutId);
    if (lock.locked) {
      this.audit.record({
        action: 'admin.login_blocked_lockout',
        actorType: 'ADMIN',
        ...client,
        metadata: { email },
      });
      throw new HttpException(lockoutMessage(lock), HttpStatus.TOO_MANY_REQUESTS);
    }

    const admin = await this.admins.findAdminByEmail(email);

    // Vérification systématique (hash factice sinon) : temps de réponse
    // comparable que le compte existe ou non.
    const valid =
      admin !== null
        ? await this.passwords.verify(admin.passwordHash, input.password)
        : (await this.passwords.hash(input.password), false);

    if (!valid || admin === null || admin.status !== AdminUserStatus.ACTIVE) {
      await this.lockout.recordFailure(lockoutId);
      this.audit.record({
        action: 'admin.login_failed',
        actorType: 'ADMIN',
        adminUserId: admin?.id,
        ...client,
        metadata: { email },
      });
      throw new UnauthorizedException(INVALID_CREDENTIALS_MESSAGE);
    }

    await this.lockout.reset(lockoutId);
    await this.admins.markLogin(admin.id);
    this.audit.record({
      action: 'admin.login',
      actorType: 'ADMIN',
      adminUserId: admin.id,
      ...client,
    });

    const accessToken = await this.jwt.signAsync(
      { adm: true },
      {
        subject: admin.id,
        secret: this.config.jwtAccessSecret,
        issuer: this.config.jwtIssuer,
        audience: ADMIN_JWT_AUDIENCE,
        expiresIn: ADMIN_TOKEN_TTL_SECONDS,
      },
    );

    return {
      accessToken,
      expiresInSeconds: ADMIN_TOKEN_TTL_SECONDS,
      admin: presentAdmin(admin),
    };
  }

  async me(adminUserId: string): Promise<AdminMe> {
    const admin = await this.admins.findAdminById(adminUserId);
    if (admin === null || admin.status !== AdminUserStatus.ACTIVE) {
      throw new UnauthorizedException('Compte administrateur introuvable ou désactivé.');
    }
    return presentAdmin(admin);
  }
}
