'use client';

import type { ManagedUserDetail } from '@carlys/api-contracts';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { ApiError, adminApi } from '@/lib/admin-api';
import { useAdminPermissions } from './use-admin-permissions';

/**
 * Suspendre ou réactiver le compte (sessions révoquées à la suspension).
 *
 * Le rôle « support » traite les signalements mais n'a pas `user:update` :
 * la fiche lui présentait pourtant un « Suspendre le compte » actif, que le
 * serveur refusait à chaque fois. Sans la permission, elle dit désormais à
 * qui s'adresser au lieu de proposer un geste voué au 403.
 */
export function UserAccountActions({ user }: { user: ManagedUserDetail }) {
  const queryClient = useQueryClient();
  const canUpdate = useAdminPermissions().includes('user:update');

  const statusMutation = useMutation({
    mutationFn: (status: 'ACTIVE' | 'SUSPENDED') => adminApi.setUserStatus(user.id, status),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['admin', 'user', user.id] });
      void queryClient.invalidateQueries({ queryKey: ['admin', 'users'] });
    },
  });

  return (
    <section className="rounded-xl bg-surface p-6 ring-1 ring-black/5">
      <h2 className="text-lg font-semibold">Compte</h2>
      <p className="mt-1 text-sm text-muted">
        Chaque action est journalisée dans l’audit. La suspension révoque immédiatement toutes les
        sessions du membre.
      </p>
      {!canUpdate && (
        <p className="mt-4 text-sm text-muted">
          Suspendre ou réactiver un compte est réservé aux administrateurs qui ont la permission
          user:update : transmets le lien de cette fiche à un super-administrateur.
        </p>
      )}
      {canUpdate && (
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
              className="rounded-lg bg-danger-strong px-4 py-2 text-sm font-semibold text-white hover:ring-2 hover:ring-danger-strong/40 disabled:opacity-50"
            >
              Suspendre le compte
            </button>
          )}
        </div>
      )}
      {statusMutation.error !== null && (
        <p className="mt-3 text-sm text-danger-ink" role="alert">
          {statusMutation.error instanceof ApiError && statusMutation.error.status === 403
            ? 'Permission manquante pour cette action.'
            : 'Action impossible, réessaie.'}
        </p>
      )}
    </section>
  );
}
