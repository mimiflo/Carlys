'use client';

import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import type { AdminAuditLog } from '@carlys/api-contracts';
import { AdminShell } from '@/components/admin-shell';
import { adminApi } from '@/lib/admin-api';

/** Journal d'audit append-only, du plus récent au plus ancien. */
export default function AuditPage() {
  const [pages, setPages] = useState<AdminAuditLog[][]>([]);
  const [cursor, setCursor] = useState<string | undefined>(undefined);
  const { data, isPending, isError } = useQuery({
    queryKey: ['admin', 'audit', cursor ?? 'first'],
    queryFn: async () => {
      const page = await adminApi.auditLogs(cursor);
      setPages((previous) => (cursor === undefined ? [page.items] : [...previous, page.items]));
      return page;
    },
  });
  const logs = pages.flat();

  return (
    <AdminShell title="Journal d’audit">
      {isError && (
        <p className="text-sm text-danger" role="alert">
          Journal indisponible — la permission audit:read est requise.
        </p>
      )}
      <div className="overflow-x-auto rounded-xl bg-surface ring-1 ring-black/5">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-black/5 text-xs uppercase tracking-wide text-muted">
            <tr>
              <th className="px-4 py-3">Date</th>
              <th className="px-4 py-3">Acteur</th>
              <th className="px-4 py-3">Action</th>
              <th className="px-4 py-3">Ressource</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((log) => (
              <tr key={log.id} className="border-b border-black/5 last:border-0">
                <td className="whitespace-nowrap px-4 py-3">
                  {new Date(log.createdAt).toLocaleString('fr-FR')}
                </td>
                <td className="px-4 py-3">{log.actorType}</td>
                <td className="px-4 py-3 font-mono text-xs">{log.action}</td>
                <td className="px-4 py-3 font-mono text-xs">
                  {log.resourceType === null ? '—' : `${log.resourceType}:${log.resourceId ?? ''}`}
                </td>
              </tr>
            ))}
            {!isPending && logs.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-6 text-center text-muted">
                  Aucun événement.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      {data?.hasMore === true && data.nextCursor !== null && (
        <button
          type="button"
          onClick={() => setCursor(data.nextCursor ?? undefined)}
          className="mt-4 rounded-lg border border-primary px-4 py-2 text-sm font-semibold text-primary hover:bg-primary hover:text-white"
        >
          Charger la suite
        </button>
      )}
    </AdminShell>
  );
}
