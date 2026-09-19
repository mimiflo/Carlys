'use client';

import { useInfiniteQuery } from '@tanstack/react-query';
import type { AdminAuditLog } from '@carlys/api-contracts';
import { AdminShell } from '@/components/admin-shell';
import { adminApi } from '@/lib/admin-api';

/** Le type d'acteur, en français : « ADMIN » n'est pas un mot de la langue. */
const ACTOR_LABELS: Record<AdminAuditLog['actorType'], string> = {
  ADMIN: 'Administration',
  USER: 'Membre',
  SYSTEM: 'Système',
};

/**
 * L'identifiant de CELUI qui a agi, selon son type.
 *
 * Le journal porte deux colonnes d'acteur — `adminUserId` et `userId` —
 * parce qu'elles pointent vers deux tables. Un seul des deux est renseigné
 * à la fois ; c'est `actorType` qui dit lequel regarder.
 */
function actorId(log: AdminAuditLog): string | null {
  return log.actorType === 'ADMIN' ? log.adminUserId : log.userId;
}

/**
 * Journal d'audit append-only, du plus récent au plus ancien.
 *
 * Les pages déjà chargées vivent dans le CACHE de la requête, pas dans un
 * état local. Elles étaient empilées par un `setState` appelé DEPUIS le
 * `queryFn` : en revenant sur la page dans les trente secondes de fraîcheur,
 * React Query servait le cache sans rejouer la fonction, l'état local
 * repartait vide, et le journal affichait « Aucun événement. » — sur une base
 * pleine, et sans le moindre moyen de s'en sortir autrement qu'en attendant.
 */
export default function AuditPage() {
  const { data, isPending, isError, fetchNextPage, hasNextPage, isFetchingNextPage } =
    useInfiniteQuery({
      queryKey: ['admin', 'audit'],
      queryFn: ({ pageParam }) => adminApi.auditLogs(pageParam),
      initialPageParam: undefined as string | undefined,
      // `undefined` = fin du journal ; c'est ce qui éteint le bouton.
      getNextPageParam: (last) =>
        last.hasMore && last.nextCursor !== null ? last.nextCursor : undefined,
    });
  const logs = data?.pages.flatMap((page) => page.items) ?? [];

  return (
    <AdminShell title="Journal d’audit">
      {isError && (
        <p className="text-sm text-danger" role="alert">
          Journal indisponible : la permission audit:read est requise.
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
              <th className="px-4 py-3">Origine</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((log) => (
              <tr key={log.id} className="border-b border-black/5 last:border-0">
                <td className="whitespace-nowrap px-4 py-3">
                  {new Date(log.createdAt).toLocaleString('fr-FR')}
                </td>
                <td className="px-4 py-3">
                  <span className="block">{ACTOR_LABELS[log.actorType]}</span>
                  {/* L'IDENTITÉ, pas seulement le type. La colonne ne rendait
                      que « ADMIN » ou « USER » — alors que le contrat porte
                      `adminUserId` et `userId` depuis toujours, et que
                      docs/architecture/admin.md promet « qui a fait quoi ».
                      Sur les quatre, la page en rendait deux. */}
                  <span className="block font-mono text-xs text-muted">{actorId(log) ?? '—'}</span>
                </td>
                <td className="px-4 py-3 font-mono text-xs">{log.action}</td>
                <td className="px-4 py-3 font-mono text-xs">
                  {log.resourceType === null ? '—' : `${log.resourceType}:${log.resourceId ?? ''}`}
                </td>
                {/* L'adresse d'où l'action est partie : c'est le « d'où »
                    d'une enquête, et le journal la porte déjà. */}
                <td className="px-4 py-3 font-mono text-xs">{log.ipAddress ?? '—'}</td>
              </tr>
            ))}
            {!isPending && logs.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-muted">
                  Aucun événement.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      {hasNextPage && (
        <button
          type="button"
          onClick={() => void fetchNextPage()}
          disabled={isFetchingNextPage}
          className="mt-4 rounded-lg border border-primary px-4 py-2 text-sm font-semibold text-primary hover:bg-primary hover:text-white disabled:opacity-50"
        >
          {isFetchingNextPage ? 'Chargement…' : 'Charger la suite'}
        </button>
      )}
    </AdminShell>
  );
}
