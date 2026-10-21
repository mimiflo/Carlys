import {
  type CanActivate,
  type ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AdminUserStatus } from '@prisma/client';
import { type Request } from 'express';
import { AppConfigService } from '../../../../config/app-config.service';
import { ADMIN_JWT_AUDIENCE } from '../../application/admin-auth.service';
import { AdminRepository, permissionsOf } from '../../infrastructure/admin.repository';

export interface AdminPrincipal {
  adminUserId: string;
  email: string;
  permissions: string[];
}

export type AdminRequest = Request & { adminPrincipal?: AdminPrincipal };

interface AdminTokenPayload {
  sub: string;
  adm?: boolean;
  /** Ouverte par un code de double authentification juste. */
  mfa?: boolean;
  /** Époque de session du compte à la signature (`AdminUser.sessionEpoch`). */
  ep?: number;
}

/**
 * Authentification du back-office : jeton JWT à audience DÉDIÉE (jamais
 * interchangeable avec un jeton mobile), compte vérifié en base à chaque
 * requête — désactiver un admin invalide immédiatement ses jetons, avancer
 * son époque de session (déconnexion, réinitialisations) aussi.
 */
@Injectable()
export class AdminAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: AppConfigService,
    private readonly admins: AdminRepository,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AdminRequest>();
    const header = request.headers.authorization;
    const [scheme, token] = typeof header === 'string' ? header.split(' ') : [];
    if (scheme !== 'Bearer' || token === undefined || token.length === 0) {
      throw new UnauthorizedException('Authentification administrateur requise.');
    }

    let payload: AdminTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<AdminTokenPayload>(token, {
        secret: this.config.jwtAccessSecret,
        algorithms: ['HS256'],
        issuer: this.config.jwtIssuer,
        audience: ADMIN_JWT_AUDIENCE,
      });
    } catch {
      throw new UnauthorizedException('Session administrateur expirée ou invalide.');
    }
    if (payload.adm !== true || payload.mfa !== true || typeof payload.sub !== 'string') {
      throw new UnauthorizedException('Session administrateur expirée ou invalide.');
    }

    // L'époque est relue en base comme le statut : la déconnexion,
    // `--reset-password` et `--reset-2fa` l'avancent, et révoquent ainsi tous
    // les jetons signés avant. Un jeton SANS époque date d'avant : refusé.
    const admin = await this.admins.findAdminById(payload.sub);
    if (
      admin === null ||
      admin.status !== AdminUserStatus.ACTIVE ||
      payload.ep !== admin.sessionEpoch
    ) {
      throw new UnauthorizedException('Session administrateur expirée ou invalide.');
    }

    request.adminPrincipal = {
      adminUserId: admin.id,
      email: admin.email,
      permissions: permissionsOf(admin),
    };
    return true;
  }
}
