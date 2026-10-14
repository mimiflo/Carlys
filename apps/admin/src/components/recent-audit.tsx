'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/admin-api';
import { auditActionLabel, auditActionTone } from '@/lib/audit-labels';
import { Badge } from './ui/badge';
import { Section } from './ui/card';
import { ArrowRightIcon } from './ui/icons';
import { unavailableMessage } from '@/lib/load-error';
import { EmptyState, ErrorState, SkeletonRows } from './ui/states';
import { AUDIT_ACTOR_LABELS } from './audit-actor';

/** Les six derniers gestes audités, pour la vue d'ensemble. */
export function RecentAudit() {
  const { data, isPending, error, refetch } = useQuery({
    // Distincte de la page Journal (`['admin', 'audit', 'pages']`, paginée).
    queryKey: ['admin', 'audit', 'apercu'],
    queryFn: () => adminApi.auditLogs(),
  });
  const logs = data?.items.slice(0, 6) ?? [];

  return (
    <Section
      title="Dernières actions"
      description="Le journal d’audit, du plus récent au plus ancien."
      actions={
        <Link
          href="/audit"
          className="inline-flex items-center gap-1.5 text-sm font-medium text-primary-ink hover:underline"
        >
          Tout le journal
          <ArrowRightIcon width={14} height={14} />
        </Link>
      }
    >
      {isPending && <SkeletonRows rows={4} />}
      {error !== null && (
        <ErrorState onRetry={() => void refetch()}>
          {unavailableMessage(error, 'Journal indisponible', 'audit:read')}
        </ErrorState>
      )}
      {data !== undefined && logs.length === 0 && (
        <EmptyState>Aucun événement pour le moment.</EmptyState>
      )}
      <ul className="divide-y divide-border">
        {logs.map((log) => (
          <li key={log.id} className="flex flex-wrap items-center justify-between gap-3 py-3">
            <div className="min-w-0">
              <Badge
                status={{ label: auditActionLabel(log.action), tone: auditActionTone(log.action) }}
              />
              <p className="mt-1 text-xs text-muted">{AUDIT_ACTOR_LABELS[log.actorType]}</p>
            </div>
            <time dateTime={log.createdAt} className="tabular-nums text-xs text-muted">
              {new Date(log.createdAt).toLocaleString('fr-FR', {
                dateStyle: 'short',
                timeStyle: 'short',
              })}
            </time>
          </li>
        ))}
      </ul>
    </Section>
  );
}
