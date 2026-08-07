import { createParamDecorator, type ExecutionContext } from '@nestjs/common';
import { type AdminPrincipal, type AdminRequest } from '../guards/admin-auth.guard';

/** Principal administrateur posé par AdminAuthGuard. */
export const CurrentAdmin = createParamDecorator(
  (_data: unknown, context: ExecutionContext): AdminPrincipal => {
    const request = context.switchToHttp().getRequest<AdminRequest>();
    const principal = request.adminPrincipal;
    if (principal === undefined) {
      throw new Error('CurrentAdmin utilisé sans AdminAuthGuard.');
    }
    return principal;
  },
);
