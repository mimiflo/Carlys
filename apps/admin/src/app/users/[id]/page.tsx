'use client';

import { useQuery } from '@tanstack/react-query';
import { useParams } from 'next/navigation';
import { AdminShell } from '@/components/admin-shell';
import { UserAccountActions } from '@/components/user-account-actions';
import { PremiumPanel } from '@/components/user-premium-panel';
import { AdminApiError, adminApi } from '@/lib/admin-api';
import { sourceLabel } from '@/lib/entitlement-labels';

/**
 * Fiche d'un compte mobile : activité, droits et leur ORIGINE, accès
 * premium (trois gestes distincts, voir `PremiumPanel`) et suspension. Les
 * gestes ne s'affichent qu'à qui a la permission de les faire ; le serveur
 * reste le seul juge.
 */
export default function UserDetailPage() {
  const params = useParams<{ id: string }>();
  const userId = params.id;

  const {
    data: user,
    isPending,
    error,
  } = useQuery({
    queryKey: ['admin', 'user', userId],
    queryFn: () => adminApi.userDetail(userId),
  });

  return (
    <AdminShell title="Fiche utilisateur">
      {isPending && <p className="text-sm text-muted">Chargement…</p>}
      {error !== null && (
        <p className="text-sm text-danger-ink" role="alert">
          {error instanceof AdminApiError && error.status === 404
            ? 'Utilisateur introuvable.'
            : 'Fiche indisponible.'}
        </p>
      )}
      {user !== undefined && (
        <div className="flex flex-col gap-6">
          <section className="rounded-xl bg-surface p-6 ring-1 ring-black/5">
            <h2 className="text-lg font-semibold">{user.displayName ?? user.email}</h2>
            <dl className="mt-4 grid grid-cols-1 gap-3 text-sm sm:grid-cols-2">
              <div>
                <dt className="text-muted">E-mail</dt>
                <dd className="font-medium">
                  {user.email} {user.emailVerified ? '(vérifié)' : '(non vérifié)'}
                </dd>
              </div>
              <div>
                <dt className="text-muted">Statut</dt>
                <dd className="font-medium">{user.status}</dd>
              </div>
              <div>
                <dt className="text-muted">Plan</dt>
                <dd className="font-medium">{user.isPremium ? 'Premium' : 'Gratuit'}</dd>
              </div>
              <div>
                <dt className="text-muted">Inscription</dt>
                <dd className="font-medium">
                  {new Date(user.createdAt).toLocaleDateString('fr-FR')}
                </dd>
              </div>
              <div>
                <dt className="text-muted">Appareils connectés</dt>
                <dd className="font-medium">{user.sessionsCount}</dd>
              </div>
              <div>
                <dt className="text-muted">Séances terminées</dt>
                <dd className="font-medium">{user.completedWorkoutsCount}</dd>
              </div>
            </dl>
          </section>

          <section className="rounded-xl bg-surface p-6 ring-1 ring-black/5">
            <h2 className="text-lg font-semibold">Droits (entitlements)</h2>
            <ul className="mt-4 flex flex-col gap-2 text-sm">
              {user.entitlements.map((entitlement) => (
                <li key={entitlement.key} className="flex items-center gap-2">
                  <span
                    aria-hidden
                    className={`inline-block h-2.5 w-2.5 rounded-full ${
                      entitlement.isActive ? 'bg-success' : 'bg-danger'
                    }`}
                  />
                  <span className="font-mono">{entitlement.key}</span>
                  <span className="text-muted">
                    {entitlement.isActive ? 'actif' : 'inactif'} · {sourceLabel(entitlement)}
                    {entitlement.expiresAt !== null &&
                      ` · expire le ${new Date(entitlement.expiresAt).toLocaleDateString('fr-FR')}`}
                  </span>
                </li>
              ))}
            </ul>
          </section>

          <PremiumPanel user={user} />
          <UserAccountActions user={user} />
        </div>
      )}
    </AdminShell>
  );
}
