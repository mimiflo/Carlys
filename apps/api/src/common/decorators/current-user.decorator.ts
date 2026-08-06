import { createParamDecorator, type ExecutionContext, UnauthorizedException } from '@nestjs/common';
import {
  type AuthenticatedPrincipal,
  type AuthenticatedRequest,
} from '../types/authenticated-request';

/**
 * Injecte le principal authentifié dans un handler :
 *   me(@CurrentUser() user: AuthenticatedPrincipal) { … }
 * Échoue explicitement si le guard n'a pas peuplé la requête.
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): AuthenticatedPrincipal => {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    if (request.authUser === undefined) {
      throw new UnauthorizedException('Authentification requise.');
    }
    return request.authUser;
  },
);
