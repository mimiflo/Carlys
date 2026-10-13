'use client';

import { type AdminCommunityReport } from '@carlys/api-contracts';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { ApiError, adminApi } from '@/lib/admin-api';
import { reportStatus } from '@/lib/status-labels';
import { Badge } from './ui/badge';
import { button } from './ui/button';

/** Préfixe des requêtes de la page : une résolution invalide TOUS les filtres. */
export const COMMUNITY_REPORTS_QUERY_KEY = ['admin', 'community-reports'] as const;

/**
 * Résoudre un signalement, ou le rouvrir si on s'est trompé.
 *
 * Résoudre ne prévient personne et ne touche pas au compte visé : c'est la
 * fiche utilisateur qui suspend. Le serveur audite chaque bascule ; ici on
 * ne fait que refléter son refus (403) sans le déguiser en panne.
 */
export function CommunityReportStatusCell({ report }: { report: AdminCommunityReport }) {
  const queryClient = useQueryClient();
  const isOpen = report.status === 'OPEN';

  const mutate = useMutation({
    mutationFn: () => adminApi.setCommunityReportStatus(report.id, isOpen ? 'RESOLVED' : 'OPEN'),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: COMMUNITY_REPORTS_QUERY_KEY }),
  });

  return (
    <div className="flex flex-col items-start gap-2">
      <Badge status={reportStatus(report.status)} />
      {report.resolvedAt !== null && !isOpen && (
        <span className="block text-xs text-muted">
          Résolu le {new Date(report.resolvedAt).toLocaleDateString('fr-FR')}
        </span>
      )}
      <button
        type="button"
        disabled={mutate.isPending}
        onClick={() => mutate.mutate()}
        className={isOpen ? button('primary', 'sm') : button('ghost', 'sm')}
      >
        {isOpen ? 'Résoudre' : 'Rouvrir'}
      </button>
      {mutate.isError && (
        <p className="mt-1 text-xs text-danger-ink" role="alert">
          {mutate.error instanceof ApiError && mutate.error.status === 403
            ? 'Permission manquante pour cette action.'
            : 'Action impossible, réessaie.'}
        </p>
      )}
    </div>
  );
}
