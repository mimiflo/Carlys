'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { AdminShell } from '@/components/admin-shell';
import { ApiStatus } from '@/components/api-status';
import { Section } from '@/components/ui/card';
import {
  ArrowRightIcon,
  CheckCircleIcon,
  DumbbellIcon,
  FlagIcon,
  SparkIcon,
  UsersIcon,
} from '@/components/ui/icons';
import { Stat } from '@/components/ui/stat';
import { ErrorState, SkeletonRows } from '@/components/ui/states';
import { useAdminPermissions } from '@/components/use-admin-permissions';
import { COMMUNITY_REPORTS_QUERY_KEY } from '@/components/community-report-status-cell';
import { RecentAudit } from '@/components/recent-audit';
import { adminApi } from '@/lib/admin-api';
import { unavailableMessage } from '@/lib/load-error';

const PERCENT = new Intl.NumberFormat('fr-FR', { style: 'percent', maximumFractionDigits: 0 });

function share(part: number, total: number): string {
  return PERCENT.format(total === 0 ? 0 : part / total);
}

function KeyFigures() {
  const { data, error, refetch } = useQuery({
    queryKey: ['admin', 'overview'],
    queryFn: adminApi.overview,
  });
  if (error !== null) {
    return (
      <ErrorState onRetry={() => void refetch()}>
        {unavailableMessage(error, 'Chiffres indisponibles', 'user:read')}
      </ErrorState>
    );
  }
  if (data === undefined) {
    return <SkeletonRows rows={2} />;
  }
  return (
    <div className="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
      <Stat label="Comptes" value={data.usersCount} icon={<UsersIcon />} />
      <Stat
        label="Membres premium"
        value={data.premiumUsersCount}
        hint={`${share(data.premiumUsersCount, data.usersCount)} des comptes`}
        icon={<SparkIcon />}
      />
      <Stat
        label="Séances terminées"
        value={data.completedWorkoutSessionsCount}
        hint={`sur ${data.workoutSessionsCount.toLocaleString('fr-FR')} commencées`}
        icon={<CheckCircleIcon />}
      />
      <Stat
        label="Exercices publiés"
        value={data.publishedExercisesCount}
        hint={`sur ${data.exercisesCount.toLocaleString('fr-FR')} au catalogue`}
        icon={<DumbbellIcon />}
      />
    </div>
  );
}

/** Les signalements en attente : le seul chiffre de la page qui appelle un geste. */
function OpenReports() {
  const { data, error, refetch } = useQuery({
    // Sa propre clé : la page Signalements range la même liste en requête
    // PAGINÉE sous `[...COMMUNITY_REPORTS_QUERY_KEY, 'OPEN']`. Partager la clé
    // mêlerait deux formes de données dans le cache. Le préfixe, lui, reste
    // commun : résoudre un signalement rafraîchit aussi ce compteur.
    queryKey: [...COMMUNITY_REPORTS_QUERY_KEY, 'OPEN', 'compteur'],
    queryFn: () => adminApi.listCommunityReports('OPEN'),
  });
  return (
    <Section
      title="Signalements à traiter"
      description="Les signalements ouverts de la communauté."
    >
      {error !== null ? (
        <ErrorState onRetry={() => void refetch()}>
          {unavailableMessage(error, 'Signalements indisponibles', 'community:moderate')}
        </ErrorState>
      ) : (
        <div className="flex items-end justify-between gap-4">
          <p className="tabular text-4xl font-semibold tracking-tight">
            {data === undefined ? '…' : `${data.items.length}${data.hasMore ? '+' : ''}`}
          </p>
          <span className="flex h-10 w-10 items-center justify-center rounded-full bg-warning/15">
            <FlagIcon />
          </span>
        </div>
      )}
      <Link
        href="/reports"
        className="mt-5 inline-flex items-center gap-1.5 text-sm font-medium text-primary-ink hover:underline"
      >
        Ouvrir la modération
        <ArrowRightIcon width={14} height={14} />
      </Link>
    </Section>
  );
}

/**
 * La vue d'ensemble : chiffres clés, santé de la plateforme, et — selon les
 * permissions — les signalements en attente et les derniers gestes audités.
 * Chaque bloc ne paraît qu'à qui peut le lire.
 */
export default function OverviewPage() {
  const permissions = useAdminPermissions();
  return (
    <AdminShell title="Vue d’ensemble" description="La plateforme Carlys d’un coup d’œil.">
      <KeyFigures />
      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <Section title="État de la plateforme" description="Relu toutes les 15 secondes.">
            <ApiStatus />
          </Section>
        </div>
        {permissions.includes('community:moderate') && <OpenReports />}
      </div>
      {permissions.includes('audit:read') && (
        <div className="mt-6">
          <RecentAudit />
        </div>
      )}
    </AdminShell>
  );
}
