import {
  adminCommunityReportSchema,
  type AdminCommunityReport,
  type CommunityReportStatus,
} from '@carlys/api-contracts';
import { call, parseData, parsePage, query, type Page } from './admin-api-client';

/**
 * Signalements de la communauté (`/admin/community`, permission
 * `community:moderate`, actions auditées côté serveur).
 *
 * Domaine à part de `admin-api.ts`, qui l'étale dans `adminApi` : la
 * modération a sa page, ses contrats et sa permission, et le client
 * d'administration reste sous sa limite de taille.
 */
export const communityApi = {
  /** Plus récents d'abord ; `status` absent = tous les statuts. */
  async listCommunityReports(
    status?: CommunityReportStatus,
    cursor?: string,
  ): Promise<Page<AdminCommunityReport>> {
    const body = await call(`/admin/community/reports${query({ status, cursor, limit: '50' })}`);
    return parsePage(body, adminCommunityReportSchema);
  },

  /** Résoudre (`RESOLVED`) ou rouvrir (`OPEN`) : rejouable sur le même statut. */
  async setCommunityReportStatus(
    id: string,
    status: CommunityReportStatus,
  ): Promise<AdminCommunityReport> {
    const body = await call(`/admin/community/reports/${id}`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    });
    return parseData(body, adminCommunityReportSchema);
  },
};
