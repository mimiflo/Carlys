'use client';

import { type AdminCommunityReport } from '@carlys/api-contracts';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { ApiError, adminApi } from '@/lib/admin-api';
import { button } from './ui/button';

/** Préfixe des requêtes de la modération : une décision rafraîchit TOUS les filtres. */
export const COMMUNITY_REPORTS_QUERY_KEY = ['admin', 'community-reports'] as const;

/**
 * Rouvrir un signalement résolu, si on s'est trompé. La décision passée
 * (contenu retiré, compte suspendu) reste écrite : rouvrir ne la défait pas,
 * le contenu retiré ne revient pas et la suspension se lève sur la fiche du
 * compte. Le serveur audite chaque bascule.
 */
export function ReportReopen({ report }: { report: AdminCommunityReport }) {
  const queryClient = useQueryClient();
  const reopen = useMutation({
    mutationFn: () => adminApi.setCommunityReportStatus(report.id, 'OPEN'),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: COMMUNITY_REPORTS_QUERY_KEY }),
  });
  return (
    <div>
      <button
        type="button"
        disabled={reopen.isPending}
        onClick={() => reopen.mutate()}
        className={button('secondary', 'sm')}
      >
        Rouvrir
      </button>
      {reopen.isError && (
        <p className="mt-2 text-xs text-danger-ink" role="alert">
          {reopen.error instanceof ApiError && reopen.error.status === 403
            ? 'Permission manquante pour cette action.'
            : 'Action impossible, réessaie.'}
        </p>
      )}
    </div>
  );
}
