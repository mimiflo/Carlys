'use client';

import { type CommunityReportStatus } from '@carlys/api-contracts';
import { useInfiniteQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { AdminShell } from '@/components/admin-shell';
import { CommunityReportRow } from '@/components/community-report-row';
import { COMMUNITY_REPORTS_QUERY_KEY } from '@/components/community-report-status-cell';
import { button } from '@/components/ui/button';
import { Segmented } from '@/components/ui/segmented';
import { ErrorState, SkeletonRows } from '@/components/ui/states';
import { TableCard, th, thead } from '@/components/ui/table';
import { useAdminPermissions } from '@/components/use-admin-permissions';
import { adminApi } from '@/lib/admin-api';
import { unavailableMessage } from '@/lib/load-error';

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
 * (une personne, un encouragement précis ou un défi entre amis), lu ici avec
 * les deux comptes et le contenu visé, du plus récent au plus ancien.
 *
 * La pagination passe par `useInfiniteQuery` plutôt que par l'accumulation
 * manuelle du journal d'audit : ici une résolution invalide la liste, et le
 * rechargement qui suit ne doit pas dédoubler les pages déjà lues.
 */
export default function ReportsPage() {
  const [filter, setFilter] = useState<StatusFilter>('OPEN');
  const status = filter === 'ALL' ? undefined : filter;
  const { data, isPending, error, fetchNextPage, hasNextPage, isFetchingNextPage, refetch } =
    useInfiniteQuery({
      queryKey: [...COMMUNITY_REPORTS_QUERY_KEY, filter],
      queryFn: ({ pageParam }) => adminApi.listCommunityReports(status, pageParam),
      initialPageParam: undefined as string | undefined,
      getNextPageParam: (last) =>
        last.hasMore && last.nextCursor !== null ? last.nextCursor : undefined,
    });
  const reports = data?.pages.flatMap((page) => page.items) ?? [];
  // Le support traite les signalements mais ne suspend pas (pas de
  // `user:update`) : l'envoyer sur la fiche « pour suspendre » le menait à un
  // bouton toujours refusé.
  const canSuspend = useAdminPermissions().includes('user:update');

  return (
    <AdminShell
      title="Signalements"
      description={
        <>
          Résoudre un signalement le classe sans prévenir personne.{' '}
          {canSuspend
            ? 'Pour agir sur un compte (suspension), ouvre sa fiche depuis le tableau.'
            : 'Suspendre un compte demande la permission user:update, que ton rôle n’a pas : transmets le lien de sa fiche à un super-administrateur.'}
        </>
      }
    >
      <div className="max-w-sm">
        <Segmented
          legend="Statut"
          name="status"
          options={STATUS_FILTERS}
          value={filter}
          onChange={setFilter}
        />
      </div>

      <div className="mt-6">
        {isPending && <SkeletonRows />}
        {error !== null && (
          <ErrorState onRetry={() => void refetch()}>
            {unavailableMessage(error, 'Signalements indisponibles', 'community:moderate')}
          </ErrorState>
        )}
        {data !== undefined && (
          <TableCard>
            <thead className={thead}>
              <tr>
                <th className={th}>Date</th>
                <th className={th}>Motif</th>
                <th className={th}>Auteur</th>
                <th className={th}>Personne visée</th>
                <th className={th}>Contenu visé</th>
                <th className={th}>Traitement</th>
              </tr>
            </thead>
            <tbody>
              {reports.map((report) => (
                <CommunityReportRow key={report.id} report={report} />
              ))}
              {reports.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-4 py-12 text-center text-sm text-muted">
                    {EMPTY_MESSAGES[filter]}
                  </td>
                </tr>
              )}
            </tbody>
          </TableCard>
        )}
        {hasNextPage && (
          <button
            type="button"
            disabled={isFetchingNextPage}
            onClick={() => void fetchNextPage()}
            className={`${button('secondary')} mt-4`}
          >
            Charger la suite
          </button>
        )}
      </div>
    </AdminShell>
  );
}
