import {
  type CanActivate,
  type ExecutionContext,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { createHash, timingSafeEqual } from 'node:crypto';
import { AppConfigService } from '../../config/app-config.service';
import { type RequestWithId } from '../../common/types/request-with-id';

function safeEquals(a: string, b: string): boolean {
  const hashA = createHash('sha256').update(a).digest();
  const hashB = createHash('sha256').update(b).digest();
  return timingSafeEqual(hashA, hashB);
}

/**
 * /metrics est libre hors production. En production, l'endpoint exige un
 * Bearer token (METRICS_TOKEN) et se comporte comme inexistant s'il n'est
 * pas configuré.
 */
@Injectable()
export class MetricsAuthGuard implements CanActivate {
  constructor(private readonly config: AppConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    if (!this.config.isProduction) {
      return true;
    }

    const token = this.config.metricsToken;
    if (token === undefined) {
      throw new NotFoundException();
    }

    const request = context.switchToHttp().getRequest<RequestWithId>();
    const header = request.headers.authorization;
    if (header === undefined || !safeEquals(header, `Bearer ${token}`)) {
      throw new UnauthorizedException('Jeton de métriques invalide.');
    }

    return true;
  }
}
