'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { AdminShell } from '@/components/admin-shell';
import { LoadMore, useCursorPages } from '@/components/cursor-pages';
import { Avatar } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { SearchForm } from '@/components/ui/search-form';
import { ErrorState, SkeletonRows } from '@/components/ui/states';
import { TableCard, td, th, thead, tr } from '@/components/ui/table';
import { adminApi, adminToken } from '@/lib/admin-api';
import { unavailableMessage } from '@/lib/load-error';
import { planStatus, userStatus } from '@/lib/status-labels';

/** Le total, en tête de page : la liste, elle, arrive par pages de vingt. */
function Totals() {
  // La coquille rend sa description AVANT la session (pré-rendu) : sans
  // jeton, la phrase fixe, et aucune requête.
  const { data } = useQuery({
    queryKey: ['admin', 'overview'],
    queryFn: adminApi.overview,
    enabled: adminToken.get() !== null,
  });
  if (data === undefined) {
    return 'Les comptes de l’application mobile.';
  }
  return `${data.usersCount.toLocaleString('fr-FR')} comptes, dont ${data.premiumUsersCount.toLocaleString('fr-FR')} premium.`;
}

/**
 * Les comptes, page par page.
 *
 * La liste ne demandait QUE la première page et n'offrait aucune suite : la
 * route sert vingt comptes par défaut et porte un curseur depuis toujours, si
 * bien que le vingt-et-unième était inatteignable — sans le moindre signe que
 * la liste était coupée. Le total annoncé en tête est le vrai.
 */
export default function UsersPage() {
  const [submitted, setSubmitted] = useState('');
  // Les comptes supprimés n'attendent plus que la purge : hors de la liste,
  // sauf à les demander.
  const [includeDeleted, setIncludeDeleted] = useState(false);
  const {
    items: users,
    data,
    isPending,
    error,
    refetch,
    ...more
  } = useCursorPages(['admin', 'users', submitted, includeDeleted], (cursor) =>
    adminApi.listUsers(submitted === '' ? undefined : submitted, cursor, includeDeleted),
  );

  return (
    <AdminShell title="Utilisateurs" description={<Totals />}>
      <SearchForm
        label="Rechercher un utilisateur"
        placeholder="Rechercher par e-mail ou nom…"
        onSubmit={setSubmitted}
      >
        <label className="flex items-center gap-2 text-sm text-muted">
          <input
            type="checkbox"
            checked={includeDeleted}
            onChange={(event) => setIncludeDeleted(event.target.checked)}
            className="h-4 w-4 accent-primary"
          />
          Voir les supprimés
        </label>
      </SearchForm>

      <div className="mt-6">
        {isPending && <SkeletonRows />}
        {error !== null && (
          <ErrorState onRetry={() => void refetch()}>
            {unavailableMessage(error, 'Liste indisponible', 'user:read')}
          </ErrorState>
        )}
        {data !== undefined && (
          <TableCard>
            <thead className={thead}>
              <tr>
                <th className={th}>Utilisateur</th>
                <th className={th}>Statut</th>
                <th className={th}>Plan</th>
                <th className={th}>Inscription</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.id} className={tr}>
                  <td className={td}>
                    <div className="flex items-center gap-3">
                      <Avatar name={user.displayName} email={user.email} />
                      <div className="min-w-0">
                        {user.displayName === null ? (
                          <span className="block text-muted">Sans nom</span>
                        ) : (
                          <span className="block truncate font-medium">{user.displayName}</span>
                        )}
                        <Link
                          href={`/users/${user.id}`}
                          className="block truncate text-xs text-primary-ink hover:underline"
                        >
                          {user.email}
                        </Link>
                      </div>
                    </div>
                  </td>
                  <td className={td}>
                    <Badge status={userStatus(user.status)} />
                  </td>
                  <td className={td}>
                    <Badge status={planStatus(user.isPremium)} />
                  </td>
                  <td data-label="Inscription" className={`${td} tabular-nums text-muted`}>
                    {new Date(user.createdAt).toLocaleDateString('fr-FR')}
                  </td>
                </tr>
              ))}
              {users.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-12 text-center text-sm text-muted">
                    Aucun utilisateur trouvé.
                  </td>
                </tr>
              )}
            </tbody>
          </TableCard>
        )}
        <LoadMore {...more} />
      </div>
    </AdminShell>
  );
}
