'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { AdminShell } from '@/components/admin-shell';
import { adminApi } from '@/lib/admin-api';

function OverviewCards() {
  const { data } = useQuery({ queryKey: ['admin', 'overview'], queryFn: adminApi.overview });
  if (data === undefined) {
    return null;
  }
  const cards = [
    { label: 'Comptes', value: data.usersCount },
    { label: 'Membres premium', value: data.premiumUsersCount },
    { label: 'Séances terminées', value: data.completedWorkoutSessionsCount },
    { label: 'Exercices publiés', value: data.publishedExercisesCount },
  ];
  return (
    <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
      {cards.map((card) => (
        <div key={card.label} className="rounded-xl bg-surface p-4 ring-1 ring-black/5">
          <p className="text-2xl font-bold">{card.value}</p>
          <p className="text-sm text-muted">{card.label}</p>
        </div>
      ))}
    </div>
  );
}

export default function UsersPage() {
  const [search, setSearch] = useState('');
  const [submitted, setSubmitted] = useState('');
  const { data, isPending, isError } = useQuery({
    queryKey: ['admin', 'users', submitted],
    queryFn: () => adminApi.listUsers(submitted === '' ? undefined : submitted),
  });

  return (
    <AdminShell title="Utilisateurs">
      <OverviewCards />
      <form
        className="mt-6 flex gap-2"
        onSubmit={(event) => {
          event.preventDefault();
          setSubmitted(search.trim());
        }}
      >
        <input
          type="search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Rechercher par e-mail ou nom…"
          aria-label="Rechercher un utilisateur"
          className="w-full max-w-sm rounded-lg border border-black/10 px-3 py-2 text-sm"
        />
        <button
          type="submit"
          className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary-dark"
        >
          Rechercher
        </button>
      </form>

      {isPending && <p className="mt-6 text-sm text-muted">Chargement…</p>}
      {isError && (
        <p className="mt-6 text-sm text-danger" role="alert">
          Liste indisponible — reconnectez-vous si le problème persiste.
        </p>
      )}
      {data !== undefined && (
        <div className="mt-6 overflow-x-auto rounded-xl bg-surface ring-1 ring-black/5">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-black/5 text-xs uppercase tracking-wide text-muted">
              <tr>
                <th className="px-4 py-3">E-mail</th>
                <th className="px-4 py-3">Nom</th>
                <th className="px-4 py-3">Statut</th>
                <th className="px-4 py-3">Plan</th>
                <th className="px-4 py-3">Inscription</th>
              </tr>
            </thead>
            <tbody>
              {data.items.map((user) => (
                <tr key={user.id} className="border-b border-black/5 last:border-0">
                  <td className="px-4 py-3">
                    <Link href={`/users/${user.id}`} className="font-medium text-primary underline">
                      {user.email}
                    </Link>
                  </td>
                  <td className="px-4 py-3">{user.displayName ?? '—'}</td>
                  <td className="px-4 py-3">{user.status}</td>
                  <td className="px-4 py-3">{user.isPremium ? 'Premium' : 'Gratuit'}</td>
                  <td className="px-4 py-3">
                    {new Date(user.createdAt).toLocaleDateString('fr-FR')}
                  </td>
                </tr>
              ))}
              {data.items.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-6 text-center text-muted">
                    Aucun utilisateur trouvé.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </AdminShell>
  );
}
