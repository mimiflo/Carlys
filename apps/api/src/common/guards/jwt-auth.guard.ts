import {
  type CanActivate,
  type ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { AppConfigService } from '../../config/app-config.service';
import { PrismaService } from '../../database/prisma/prisma.service';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { type AuthenticatedRequest } from '../types/authenticated-request';

interface AccessTokenPayload {
  sub: string;
  sid: string;
}

/**
 * Guard global : toute route est authentifiée sauf marquage @Public().
 *
 * Vérifie le JWT (signature, expiration, issuer, audience) PUIS l'état de la
 * session en base : révoquer une session invalide immédiatement ses access
 * tokens, sans attendre leur expiration.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    private readonly config: AppConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic === true) {
      return true;
    }

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const token = this.extractBearerToken(request);
    if (token === undefined) {
      throw new UnauthorizedException('Authentification requise.');
    }

    let payload: AccessTokenPayload;
    try {
      payload = await this.jwt.verifyAsync<AccessTokenPayload>(token, {
        secret: this.config.jwtAccessSecret,
        issuer: this.config.jwtIssuer,
        audience: this.config.jwtAudience,
      });
    } catch {
      throw new UnauthorizedException('Session expirée ou invalide.');
    }

    if (typeof payload.sub !== 'string' || typeof payload.sid !== 'string') {
      throw new UnauthorizedException('Session expirée ou invalide.');
    }

    const session = await this.prisma.userSession.findUnique({
      where: { id: payload.sid },
      select: { userId: true, revokedAt: true, expiresAt: true },
    });
    const sessionValid =
      session !== null &&
      session.userId === payload.sub &&
      session.revokedAt === null &&
      session.expiresAt.getTime() > Date.now();
    if (!sessionValid) {
      throw new UnauthorizedException('Session expirée ou invalide.');
    }

    request.authUser = { userId: payload.sub, sessionId: payload.sid };
    return true;
  }

  private extractBearerToken(request: AuthenticatedRequest): string | undefined {
    const header = request.headers.authorization;
    if (typeof header !== 'string') {
      return undefined;
    }
    const [scheme, token] = header.split(' ');
    return scheme === 'Bearer' && token !== undefined && token.length > 0 ? token : undefined;
  }
}
