import { requestIdOf, type RequestWithId } from '../../../../common/types/request-with-id';
import { type AdminActor } from '../../../audit/audit.service';
import { type AdminPrincipal } from '../guards/admin-auth.guard';

/**
 * Qui a fait quoi, d'où : l'empreinte que tout geste du back-office laisse
 * dans le journal d'audit. Partagée par tous les contrôleurs d'administration.
 */
export function actorOf(admin: AdminPrincipal, request: RequestWithId): AdminActor {
  return {
    adminUserId: admin.adminUserId,
    ipAddress: request.ip,
    requestId: requestIdOf(request),
  };
}
