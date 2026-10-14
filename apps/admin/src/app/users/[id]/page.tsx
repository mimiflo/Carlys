'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { useParams } from 'next/navigation';
import type { ReactNode } from 'react';
import { AdminShell } from '@/components/admin-shell';
import { Avatar } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { button } from '@/components/ui/button';
import { Card, Section } from '@/components/ui/card';
import { ArrowLeftIcon } from '@/components/ui/icons';
import { ErrorState, SkeletonRows } from '@/components/ui/states';
import { UserAccountActions } from '@/components/user-account-actions';
import { PremiumPanel } from '@/components/user-premium-panel';
import { ApiError, adminApi } from '@/lib/admin-api';
import { sourceLabel } from '@/lib/entitlement-labels';
import { entitlementStatus, planStatus, userStatus } from '@/lib/status-labels';

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
    <AdminShell
      title="Fiche utilisateur"
      actions={
        <Link href="/users" className={button('secondary', 'sm')}>
          <ArrowLeftIcon width={14} height={14} />
          Utilisateurs
        </Link>
      }
    >
      {isPending && <SkeletonRows rows={4} />}
      {error !== null && (
        <ErrorState>
          {error instanceof ApiError && error.status === 404
            ? 'Utilisateur introuvable.'
            : 'Fiche indisponible.'}
        </ErrorState>
      )}
      {user !== undefined && (
        <div className="flex flex-col gap-6">
          <Card className="p-6">
            <div className="flex flex-wrap items-center gap-4">
              <Avatar name={user.displayName} email={user.email} size="lg" />
              <div className="min-w-48 flex-1">
                <h2 className="truncate text-lg font-semibold">{user.displayName ?? user.email}</h2>
                <p className="truncate text-sm text-muted">{user.email}</p>
              </div>
              <div className="flex flex-wrap gap-2">
                <Badge status={userStatus(user.status)} />
                <Badge status={planStatus(user.isPremium)} />
              </div>
            </div>
            <dl className="mt-6 grid grid-cols-2 gap-x-6 gap-y-5 border-t border-border pt-6 text-sm sm:grid-cols-4">
              <Fact label="E-mail">{user.emailVerified ? 'Vérifié' : 'Non vérifié'}</Fact>
              <Fact label="Inscription">
                {new Date(user.createdAt).toLocaleDateString('fr-FR')}
              </Fact>
              <Fact label="Appareils connectés">{user.sessionsCount}</Fact>
              <Fact label="Séances terminées">{user.completedWorkoutsCount}</Fact>
            </dl>
          </Card>

          <Section
            title="Droits"
            description="Ce que le compte peut utiliser, et d’où vient chaque droit."
          >
            <ul className="divide-y divide-border">
              {user.entitlements.map((entitlement) => (
                <li
                  key={entitlement.key}
                  className="flex flex-wrap items-center justify-between gap-3 py-3 text-sm"
                >
                  <div>
                    <span className="font-mono text-xs">{entitlement.key}</span>
                    <span className="block text-muted">
                      {sourceLabel(entitlement)}
                      {entitlement.expiresAt !== null &&
                        ` · expire le ${new Date(entitlement.expiresAt).toLocaleDateString('fr-FR')}`}
                    </span>
                  </div>
                  <Badge status={entitlementStatus(entitlement)} />
                </li>
              ))}
            </ul>
          </Section>

          <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
            <PremiumPanel user={user} />
            <UserAccountActions user={user} />
          </div>
        </div>
      )}
    </AdminShell>
  );
}

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div>
      <dt className="text-xs text-muted">{label}</dt>
      <dd className="tabular mt-1 font-medium">{children}</dd>
    </div>
  );
}
