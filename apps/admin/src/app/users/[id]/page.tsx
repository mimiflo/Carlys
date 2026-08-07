'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useParams } from 'next/navigation';
import { AdminShell } from '@/components/admin-shell';
import { AdminApiError, adminApi } from '@/lib/admin-api';

/**
 * Fiche d'un compte mobile : activité, droits, actions sensibles
 * (suspension = sessions révoquées ; attribution manuelle = auditée).
 */
export default function UserDetailPage() {
  const params = useParams<{ id: string }>();
  const userId = params.id;
  const queryClient = useQueryClient();

  const {
    data: user,
    isPending,
    error,
  } = useQuery({
    queryKey: ['admin', 'user', userId],
    queryFn: () => adminApi.userDetail(userId),
  });

  const refresh = () => {
    void queryClient.invalidateQueries({ queryKey: ['admin', 'user', userId] });
    void queryClient.invalidateQueries({ queryKey: ['admin', 'users'] });
  };
  const statusMutation = useMutation({
    mutationFn: (status: 'ACTIVE' | 'SUSPENDED') => adminApi.setUserStatus(userId, status),
    onSuccess: refresh,
  });
  const entitlementMutation = useMutation({
    mutationFn: (isActive: boolean) =>
      adminApi.setEntitlement(userId, 'premium_exercises', isActive),
    onSuccess: refresh,
  });
  const actionError = statusMutation.error ?? entitlementMutation.error;

  return (
    <AdminShell title="Fiche utilisateur">
      {isPending && <p className="text-sm text-muted">Chargement…</p>}
      {error !== null && (
        <p className="text-sm text-danger" role="alert">
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
                    {entitlement.isActive ? 'actif' : 'inactif'}
                    {entitlement.expiresAt !== null &&
                      ` — expire le ${new Date(entitlement.expiresAt).toLocaleDateString('fr-FR')}`}
                  </span>
                </li>
              ))}
            </ul>
          </section>

          <section className="rounded-xl bg-surface p-6 ring-1 ring-black/5">
            <h2 className="text-lg font-semibold">Actions</h2>
            <p className="mt-1 text-sm text-muted">
              Chaque action est journalisée dans l’audit. La suspension révoque immédiatement toutes
              les sessions de l’utilisateur.
            </p>
            <div className="mt-4 flex flex-wrap gap-3">
              {user.status === 'SUSPENDED' ? (
                <button
                  type="button"
                  disabled={statusMutation.isPending}
                  onClick={() => statusMutation.mutate('ACTIVE')}
                  className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary-dark disabled:opacity-50"
                >
                  Réactiver le compte
                </button>
              ) : (
                <button
                  type="button"
                  disabled={statusMutation.isPending || user.status === 'DELETED'}
                  onClick={() => statusMutation.mutate('SUSPENDED')}
                  className="rounded-lg bg-danger px-4 py-2 text-sm font-semibold text-white hover:opacity-90 disabled:opacity-50"
                >
                  Suspendre le compte
                </button>
              )}
              <button
                type="button"
                disabled={entitlementMutation.isPending}
                onClick={() => entitlementMutation.mutate(!user.isPremium)}
                className="rounded-lg border border-primary px-4 py-2 text-sm font-semibold text-primary hover:bg-primary hover:text-white disabled:opacity-50"
              >
                {user.isPremium ? 'Retirer le premium manuel' : 'Accorder le premium (manuel)'}
              </button>
            </div>
            {actionError !== null && (
              <p className="mt-3 text-sm text-danger" role="alert">
                {actionError instanceof AdminApiError && actionError.status === 403
                  ? 'Permission manquante pour cette action.'
                  : 'Action impossible — réessayez.'}
              </p>
            )}
          </section>
        </div>
      )}
    </AdminShell>
  );
}
