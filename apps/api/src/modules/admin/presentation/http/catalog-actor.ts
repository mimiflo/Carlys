import { requestIdOf, type RequestWithId } from '../../../../common/types/request-with-id';
import { type CatalogActor } from '../../application/admin-catalog.service';
import { type AdminPrincipal } from '../guards/admin-auth.guard';

/**
 * Qui a fait quoi, d'où : l'empreinte que tout geste de catalogue laisse dans
 * le journal d'audit. Partagée par les deux contrôleurs du catalogue.
 */
export function actorOf(admin: AdminPrincipal, request: RequestWithId): CatalogActor {
  return {
    adminUserId: admin.adminUserId,
    ipAddress: request.ip,
    requestId: requestIdOf(request),
  };
}
