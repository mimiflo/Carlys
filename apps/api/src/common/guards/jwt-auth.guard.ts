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
import { SessionCache } from '../../infrastructure/cache/session-cache';
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
 * session : révoquer une session invalide immédiatement ses access tokens,
 * sans attendre leur expiration. L'état se lit d'abord dans [SessionCache],
 * que toute fermeture invalide ; la base, sinon.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    private readonly config: AppConfigService,
    private readonly prisma: PrismaService,
    private readonly sessions: SessionCache,
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
        algorithms: ['HS256'],
        issuer: this.config.jwtIssuer,
        audience: this.config.jwtAudience,
      });
    } catch {
      throw new UnauthorizedException('Session expirée ou invalide.');
    }

    if (typeof payload.sub !== 'string' || typeof payload.sid !== 'string') {
      throw new UnauthorizedException('Session expirée ou invalide.');
    }

    if (!(await this.sessionValid(payload))) {
      throw new UnauthorizedException('Session expirée ou invalide.');
    }

    request.authUser = { userId: payload.sub, sessionId: payload.sid };
    return true;
  }

  private async sessionValid({ sub, sid }: AccessTokenPayload): Promise<boolean> {
    const cached = await this.sessions.lookup(sub, sid);
    if (cached?.expiresAt != null && cached.expiresAt > Date.now()) {
      return true;
    }
    const session = await this.prisma.userSession.findUnique({
      where: { id: sid },
      select: { userId: true, revokedAt: true, expiresAt: true },
    });
    const valid =
      session !== null &&
      session.userId === sub &&
      session.revokedAt === null &&
      session.expiresAt.getTime() > Date.now();
    if (valid && cached !== null) {
      // Sans attendre : la requête n'a pas à payer l'écriture du cache.
      void this.sessions.remember(sub, sid, session.expiresAt, cached.generation);
    }
    return valid;
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
