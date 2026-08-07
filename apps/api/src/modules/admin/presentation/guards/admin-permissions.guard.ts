import {
  type CanActivate,
  type ExecutionContext,
  ForbiddenException,
  Injectable,
  SetMetadata,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { type AdminRequest } from './admin-auth.guard';

export const REQUIRED_PERMISSIONS_KEY = 'admin:requiredPermissions';

/** Permissions `ressource:action` exigées pour la route (toutes requises). */
export const RequirePermissions = (...permissions: string[]) =>
  SetMetadata(REQUIRED_PERMISSIONS_KEY, permissions);

/** RBAC : vérifie les permissions du principal posé par AdminAuthGuard. */
@Injectable()
export class AdminPermissionsGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<string[] | undefined>(
      REQUIRED_PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (required === undefined || required.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest<AdminRequest>();
    const principal = request.adminPrincipal;
    if (principal === undefined) {
      // AdminAuthGuard doit précéder ce guard — refus sûr sinon.
      throw new UnauthorizedException('Authentification administrateur requise.');
    }

    const granted = new Set(principal.permissions);
    const missing = required.filter((permission) => !granted.has(permission));
    if (missing.length > 0) {
      throw new ForbiddenException(`Permission manquante : ${missing.join(', ')}.`);
    }
    return true;
  }
}
