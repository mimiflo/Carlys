'use client';

import { AdminShell } from '@/components/admin-shell';
import { AUDIT_ACTOR_LABELS, auditActorId } from '@/components/audit-actor';
import { LoadMore, useCursorPages } from '@/components/cursor-pages';
import { Badge } from '@/components/ui/badge';
import { TableCard, td, th, thead, tr } from '@/components/ui/table';
import { ErrorState, SkeletonRows } from '@/components/ui/states';
import { adminApi } from '@/lib/admin-api';
import { auditActionLabel, auditActionTone } from '@/lib/audit-labels';
import { unavailableMessage } from '@/lib/load-error';

export default function AuditPage() {
  const {
    items: logs,
    data,
    isPending,
    error,
    refetch,
    ...more
  } = useCursorPages(['admin', 'audit', 'pages'], (cursor) => adminApi.auditLogs(cursor));

  return (
    <AdminShell
      title="Journal d’audit"
      description="Chaque geste sensible, qui l’a fait et d’où. Le journal ne s’efface pas."
    >
      {error !== null && (
        <ErrorState onRetry={() => void refetch()}>
          {unavailableMessage(error, 'Journal indisponible', 'audit:read')}
        </ErrorState>
      )}
      {isPending && <SkeletonRows />}
      {data !== undefined && (
        <TableCard>
          <thead className={thead}>
            <tr>
              <th className={th}>Date</th>
              <th className={th}>Acteur</th>
              <th className={th}>Action</th>
              <th className={th}>Ressource</th>
              <th className={th}>Origine</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((log) => (
              <tr key={log.id} className={tr}>
                <td className={`${td} tabular-nums whitespace-nowrap text-muted`}>
                  {new Date(log.createdAt).toLocaleString('fr-FR')}
                </td>
                <td data-label="Acteur" className={td}>
                  <span className="block font-medium">{AUDIT_ACTOR_LABELS[log.actorType]}</span>
                  {/* L'IDENTITÉ, pas seulement le type. La colonne ne rendait
                      que « ADMIN » ou « USER » — alors que le contrat porte
                      `adminUserId` et `userId` depuis toujours, et que
                      docs/architecture/admin.md promet « qui a fait quoi ».
                      Sur les quatre, la page en rendait deux. */}
                  <span className="block font-mono text-xs text-muted">
                    {auditActorId(log) ?? '—'}
                  </span>
                </td>
                <td className={`${td} max-md:basis-full`}>
                  <Badge
                    status={{
                      label: auditActionLabel(log.action),
                      tone: auditActionTone(log.action),
                    }}
                  />
                  {auditActionLabel(log.action) !== log.action && (
                    <span className="mt-1 block font-mono text-xs text-muted">{log.action}</span>
                  )}
                </td>
                <td data-label="Ressource" className={`${td} font-mono text-xs max-md:break-all`}>
                  {log.resourceType === null ? '—' : `${log.resourceType}:${log.resourceId ?? ''}`}
                </td>
                {/* L'adresse d'où l'action est partie : c'est le « d'où »
                    d'une enquête, et le journal la porte déjà. */}
                <td data-label="Origine" className={`${td} font-mono text-xs`}>
                  {log.ipAddress ?? '—'}
                </td>
              </tr>
            ))}
            {logs.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-12 text-center text-sm text-muted">
                  Aucun événement.
                </td>
              </tr>
            )}
          </tbody>
        </TableCard>
      )}
      <LoadMore {...more} />
    </AdminShell>
  );
}
