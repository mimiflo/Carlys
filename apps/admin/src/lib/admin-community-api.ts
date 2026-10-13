import {
  adminCommunityReportSchema,
  type AdminCommunityReport,
  type AdminCommunityReportFilters,
  type CommunityReportDecision,
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
  /**
   * Plus récents d'abord ; `status` absent = tous les statuts. Les filtres
   * (motif, personne signalée) viennent en dernier : les appels existants
   * `(status, cursor)` restent valables.
   */
  async listCommunityReports(
    status?: CommunityReportStatus,
    cursor?: string,
    filters: AdminCommunityReportFilters = {},
  ): Promise<Page<AdminCommunityReport>> {
    const body = await call(
      `/admin/community/reports${query({ status, ...filters, cursor, limit: '50' })}`,
    );
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

  /**
   * Trancher un signalement ouvert : retirer le contenu, suspendre (exige
   * aussi `user:update` et une note), ou classer — il est résolu ensuite.
   */
  async decideCommunityReport(
    id: string,
    decision: CommunityReportDecision,
  ): Promise<AdminCommunityReport> {
    const body = await call(`/admin/community/reports/${id}/decision`, {
      method: 'POST',
      body: JSON.stringify(decision),
    });
    return parseData(body, adminCommunityReportSchema);
  },
};
