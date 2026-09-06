'use client';

import { type AdminCommunityReport } from '@carlys/api-contracts';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { AdminApiError, adminApi } from '@/lib/admin-api';

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
    <div>
      {report.resolvedAt !== null && !isOpen && (
        <span className="block text-xs text-muted">
          Résolu le {new Date(report.resolvedAt).toLocaleDateString('fr-FR')}
        </span>
      )}
      <button
        type="button"
        disabled={mutate.isPending}
        onClick={() => mutate.mutate()}
        className={
          isOpen
            ? 'rounded-lg bg-primary px-3 py-1 text-xs font-semibold text-white hover:bg-primary-dark disabled:opacity-50'
            : 'rounded-lg px-3 py-1 text-xs font-semibold text-primary hover:bg-primary/10 disabled:opacity-50'
        }
      >
        {isOpen ? 'Résoudre' : 'Rouvrir'}
      </button>
      {mutate.isError && (
        <p className="mt-1 text-xs text-danger" role="alert">
          {mutate.error instanceof AdminApiError && mutate.error.status === 403
            ? 'Permission manquante pour cette action.'
            : 'Action impossible, réessayez.'}
        </p>
      )}
    </div>
  );
}
