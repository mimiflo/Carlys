'use client';

import { type CommunityReportStatus } from '@carlys/api-contracts';
import { useInfiniteQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { AdminShell } from '@/components/admin-shell';
import { CommunityReportRow } from '@/components/community-report-row';
import { COMMUNITY_REPORTS_QUERY_KEY } from '@/components/community-report-status-cell';
import { AdminApiError, adminApi } from '@/lib/admin-api';

type StatusFilter = CommunityReportStatus | 'ALL';

const STATUS_FILTERS: ReadonlyArray<{ value: StatusFilter; label: string }> = [
  { value: 'OPEN', label: 'Ouverts' },
  { value: 'RESOLVED', label: 'Résolus' },
  { value: 'ALL', label: 'Tous' },
];

const EMPTY_MESSAGES: Record<StatusFilter, string> = {
  OPEN: 'Aucun signalement ouvert.',
  RESOLVED: 'Aucun signalement résolu.',
  ALL: 'Aucun signalement.',
};

/**
 * Signalements de la communauté : ce que les membres remontent depuis l'app
 * (une personne, ou un encouragement précis), lu ici avec les deux comptes
 * et le texte visé, du plus récent au plus ancien.
 *
 * La pagination passe par `useInfiniteQuery` plutôt que par l'accumulation
 * manuelle du journal d'audit : ici une résolution invalide la liste, et le
 * rechargement qui suit ne doit pas dédoubler les pages déjà lues.
 */
export default function ReportsPage() {
  const [filter, setFilter] = useState<StatusFilter>('OPEN');
  const status = filter === 'ALL' ? undefined : filter;
  const { data, isPending, error, fetchNextPage, hasNextPage, isFetchingNextPage } =
    useInfiniteQuery({
      queryKey: [...COMMUNITY_REPORTS_QUERY_KEY, filter],
      queryFn: ({ pageParam }) => adminApi.listCommunityReports(status, pageParam),
      initialPageParam: undefined as string | undefined,
      getNextPageParam: (last) =>
        last.hasMore && last.nextCursor !== null ? last.nextCursor : undefined,
    });
  const reports = data?.pages.flatMap((page) => page.items) ?? [];

  return (
    <AdminShell title="Signalements">
      <p className="text-sm text-muted">
        Résoudre un signalement le classe sans prévenir personne. Pour agir sur un compte
        (suspension), ouvrez sa fiche depuis le tableau.
      </p>

      <fieldset className="mt-6">
        <legend className="text-sm font-medium">Statut</legend>
        <div className="mt-2 flex flex-wrap gap-4">
          {STATUS_FILTERS.map((option) => (
            <label key={option.value} className="flex items-center gap-2 text-sm">
              <input
                type="radio"
                name="status"
                value={option.value}
                checked={filter === option.value}
                onChange={() => setFilter(option.value)}
              />
              {option.label}
            </label>
          ))}
        </div>
      </fieldset>

      {isPending && <p className="mt-6 text-sm text-muted">Chargement…</p>}
      {error !== null && (
        <p className="mt-6 text-sm text-danger" role="alert">
          {error instanceof AdminApiError && error.status === 403
            ? 'Signalements indisponibles : la permission community:moderate est requise.'
            : 'Signalements indisponibles : reconnectez-vous si le problème persiste.'}
        </p>
      )}
      {data !== undefined && (
        <div className="mt-6 overflow-x-auto rounded-xl bg-surface ring-1 ring-black/5">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-black/5 text-xs uppercase tracking-wide text-muted">
              <tr>
                <th className="px-4 py-3">Date</th>
                <th className="px-4 py-3">Motif</th>
                <th className="px-4 py-3">Auteur</th>
                <th className="px-4 py-3">Personne visée</th>
                <th className="px-4 py-3">Encouragement visé</th>
                <th className="px-4 py-3">Traitement</th>
              </tr>
            </thead>
            <tbody>
              {reports.map((report) => (
                <CommunityReportRow key={report.id} report={report} />
              ))}
              {reports.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-6 text-center text-muted">
                    {EMPTY_MESSAGES[filter]}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
      {hasNextPage && (
        <button
          type="button"
          disabled={isFetchingNextPage}
          onClick={() => void fetchNextPage()}
          className="mt-4 rounded-lg border border-primary px-4 py-2 text-sm font-semibold text-primary hover:bg-primary hover:text-white disabled:opacity-50"
        >
          Charger la suite
        </button>
      )}
    </AdminShell>
  );
}
