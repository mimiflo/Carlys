import {
  type AdminLoginChallenge,
  type AdminLoginResult,
  type AdminMe,
  adminPermissionSchema,
} from '@carlys/api-contracts';
import {
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AdminUserStatus } from '@prisma/client';
import { logFingerprint } from '../../../common/utilities/log-privacy';
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
import { AdminTotpService, EXPIRED_CHALLENGE_MESSAGE } from './admin-totp.service';

/** Audience JWT dédiée : un jeton admin n'est JAMAIS accepté côté mobile (et inversement). */
export const ADMIN_JWT_AUDIENCE = 'carlys-admin';
/** Durée de vie du jeton admin — pas de refresh : reconnexion quotidienne. */
const ADMIN_TOKEN_TTL_SECONDS = 12 * 3_600;

const INVALID_CREDENTIALS_MESSAGE = 'E-mail ou mot de passe incorrect.';
const INVALID_CODE_MESSAGE = 'Code incorrect ou déjà utilisé.';
const FROZEN_TOTP_MESSAGE =
  'Trop de codes faux : la double authentification de ce compte est gelée. L’opérateur du serveur doit la réinitialiser (--reset-2fa), et le mot de passe se change.';

/**
 * Compteur de verrouillage propre au back-office : même politique que le
 * mobile (LockoutService), mais un compte admin et un compte mobile de même
 * adresse ne partagent jamais leurs échecs.
 */
function adminLockoutIdentifier(email: string): string {
  return `admin:${email}`;
}

/** Les essais de CODE se comptent à part, par compte : six chiffres se devinent. */
function totpLockoutIdentifier(adminUserId: string): string {
  return `admin-totp:${adminUserId}`;
}

function presentAdmin(admin: AdminWithAccess): AdminMe {
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
    private readonly totp: AdminTotpService,
  ) {}

  /**
   * PREMIÈRE étape : le mot de passe. Juste, il n'ouvre pas la session mais
   * la seconde étape, le code de l'appli d'authentification.
   */
  async login(
    input: { email: string; password: string },
    client: { ipAddress?: string; userAgent?: string },
  ): Promise<AdminLoginChallenge> {
    const email = input.email.trim().toLowerCase();
    const lockoutId = adminLockoutIdentifier(email);
    // L'audit ne garde de l'adresse saisie que son empreinte à clé, comme la
    // connexion mobile : il survit aux comptes, et se lit au back-office.
    const emailHash = logFingerprint(email, this.config.logFingerprintKey);

    // Verrouillé : refus AVANT toute lecture du compte, sans révéler s'il existe.
    // L'essai est RÉSERVÉ, pas lu puis compté après la vérification : sinon
    // une rafale simultanée, une requête par adresse IP, passait tout entière
    // sous le seuil (LockoutService.reserveAttempt).
    const lock = await this.lockout.reserveAttempt(lockoutId);
    if (lock.locked) {
      this.audit.record({
        action: 'admin.login_blocked_lockout',
        actorType: 'ADMIN',
        ...client,
        metadata: { emailHash },
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
      this.audit.record({
        action: 'admin.login_failed',
        actorType: 'ADMIN',
        adminUserId: admin?.id,
        ...client,
        metadata: { emailHash },
      });
      throw new UnauthorizedException(INVALID_CREDENTIALS_MESSAGE);
    }

    await this.lockout.reset(lockoutId);
    if (admin.totpSecret === null) {
      this.audit.record({
        action: 'admin.totp_not_issued',
        actorType: 'ADMIN',
        adminUserId: admin.id,
        ...client,
      });
    }
    return this.totp.challengeFor(admin);
  }

  /**
   * SECONDE étape : le code à 6 chiffres. Juste et inutilisé, il ouvre la
   * session — et confirme l'enrôlement si c'était le premier.
   */
  async verifySecondFactor(
    input: { challengeToken: string; code: string },
    client: { ipAddress?: string; userAgent?: string },
  ): Promise<AdminLoginResult> {
    const adminUserId = await this.totp.adminIdOf(input.challengeToken);
    const lock = await this.lockout.reserveAttempt(totpLockoutIdentifier(adminUserId));
    if (lock.locked) {
      this.audit.record({
        action: 'admin.totp_blocked_lockout',
        actorType: 'ADMIN',
        adminUserId,
        ...client,
      });
      throw new HttpException(lockoutMessage(lock), HttpStatus.TOO_MANY_REQUESTS);
    }
    // Le verrou Redis RALENTIT (et cède si Redis tombe) ; celui-ci, en base,
    // PLAFONNE : au-delà, plus aucun code n'est vérifié avant `--reset-2fa`.
    if (!(await this.admins.reserveTotpAttempt(adminUserId))) {
      this.audit.record({
        action: 'admin.totp_frozen',
        actorType: 'ADMIN',
        adminUserId,
        ...client,
      });
      throw new ForbiddenException(FROZEN_TOTP_MESSAGE);
    }
    const admin = await this.admins.findAdminById(adminUserId);
    if (admin === null || admin.status !== AdminUserStatus.ACTIVE) {
      throw new UnauthorizedException(EXPIRED_CHALLENGE_MESSAGE);
    }
    const enrolling = admin.totpEnabledAt === null;
    if (!(await this.totp.consumeCode(admin, input.code))) {
      this.audit.record({
        action: 'admin.totp_failed',
        actorType: 'ADMIN',
        adminUserId,
        ...client,
      });
      throw new UnauthorizedException(INVALID_CODE_MESSAGE);
    }

    await this.lockout.reset(totpLockoutIdentifier(adminUserId));
    await this.admins.markLogin(admin.id);
    if (enrolling) {
      this.audit.record({
        action: 'admin.totp_enrolled',
        actorType: 'ADMIN',
        adminUserId,
        ...client,
      });
    }
    this.audit.record({
      action: 'admin.login',
      actorType: 'ADMIN',
      adminUserId: admin.id,
      ...client,
    });

    const accessToken = await this.jwt.signAsync(
      // `mfa` : la session vient d'un code juste. Le garde l'EXIGE, et refuse
      // donc les sessions ouvertes au seul mot de passe, d'avant la 2FA.
      { adm: true, mfa: true },
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
