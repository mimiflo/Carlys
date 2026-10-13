'use client';

import { type CommunityReportReason, type CommunityReportStatus } from '@carlys/api-contracts';
import { useInfiniteQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { AdminShell } from '@/components/admin-shell';
import { CommunityReportRow } from '@/components/community-report-row';
import { COMMUNITY_REPORTS_QUERY_KEY } from '@/components/community-report-status-cell';
import { ReportSheet } from '@/components/report-sheet';
import { button, field } from '@/components/ui/button';
import { CloseIcon } from '@/components/ui/icons';
import { Segmented } from '@/components/ui/segmented';
import { ErrorState, SkeletonRows } from '@/components/ui/states';
import { TableCard, th, thead } from '@/components/ui/table';
import { useAdminPermissions } from '@/components/use-admin-permissions';
import { adminApi } from '@/lib/admin-api';
import { unavailableMessage } from '@/lib/load-error';
import { COMMUNITY_REPORT_REASON_LABELS } from '@/lib/report-labels';

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
  const [reason, setReason] = useState<CommunityReportReason | ''>('');
  // La personne dont on lit l'historique : son nom pour la puce de filtre.
  const [person, setPerson] = useState<{ id: string; label: string } | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const status = filter === 'ALL' ? undefined : filter;
  const filters = {
    ...(reason === '' ? {} : { reason }),
    ...(person === null ? {} : { reportedUserId: person.id }),
  };
  const { data, isPending, error, fetchNextPage, hasNextPage, isFetchingNextPage, refetch } =
    useInfiniteQuery({
      queryKey: [...COMMUNITY_REPORTS_QUERY_KEY, filter, reason || 'ALL', person?.id ?? 'ALL'],
      queryFn: ({ pageParam }) => adminApi.listCommunityReports(status, pageParam, filters),
      initialPageParam: undefined as string | undefined,
      getNextPageParam: (last) =>
        last.hasMore && last.nextCursor !== null ? last.nextCursor : undefined,
    });
  const reports = data?.pages.flatMap((page) => page.items) ?? [];
  // Le support traite les signalements mais ne suspend pas (pas de
  // `user:update`) : la décision le dit au lieu de proposer un geste refusé.
  const canSuspend = useAdminPermissions().includes('user:update');
  const selected = reports.find((report) => report.id === selectedId);

  return (
    <AdminShell
      title="Signalements"
      description="Ce que les membres remontent depuis l’application. Ouvre un signalement pour trancher : retirer le contenu, suspendre le compte, ou classer sans suite. Chaque décision est journalisée."
    >
      <div className="flex flex-wrap items-center gap-3">
        <div className="w-full max-w-sm">
          <Segmented
            legend="Statut"
            name="status"
            options={STATUS_FILTERS}
            value={filter}
            onChange={(next) => {
              // Changer de filtre referme le dossier : sinon un signalement
              // sorti de la liste (tranché) se rouvrirait en y revenant.
              setSelectedId(null);
              setFilter(next);
            }}
          />
        </div>
        <select
          aria-label="Motif"
          value={reason}
          onChange={(event) => setReason(event.target.value as CommunityReportReason | '')}
          className={`${field} h-9 max-w-56 pr-8`}
        >
          <option value="">Tous les motifs</option>
          {Object.entries(COMMUNITY_REPORT_REASON_LABELS).map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
        {person !== null && (
          <span className="inline-flex h-9 items-center gap-2 rounded-lg bg-primary/10 pr-1 pl-3 text-sm text-primary-ink">
            Signalements visant {person.label}
            <button
              type="button"
              onClick={() => setPerson(null)}
              aria-label="Retirer le filtre de personne"
              className="rounded-md p-1 hover:bg-primary/15"
            >
              <CloseIcon width={14} height={14} />
            </button>
          </span>
        )}
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
                <CommunityReportRow
                  key={report.id}
                  report={report}
                  onOpen={() => setSelectedId(report.id)}
                />
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

      {selected !== undefined && (
        <ReportSheet
          report={selected}
          canSuspend={canSuspend}
          onShowPersonReports={() => {
            setPerson({
              id: selected.reportedUserId,
              label: selected.reportedUser.displayName ?? selected.reportedUser.email,
            });
            setFilter('ALL');
            setSelectedId(null);
          }}
          onDecided={() => setSelectedId(null)}
          onClose={() => setSelectedId(null)}
        />
      )}
    </AdminShell>
  );
}
