'use client';

import { healthReportSchema, type HealthReport } from '@carlys/api-contracts';
import { useQuery } from '@tanstack/react-query';
import { publicEnv } from '@/lib/env';

async function fetchHealth(): Promise<HealthReport> {
  const response = await fetch(`${publicEnv.apiBaseUrl}/health`, {
    cache: 'no-store',
  });
  // /health répond 200 (ok) ou 503 (dégradé) avec le même corps JSON.
  const body: unknown = await response.json();
  return healthReportSchema.parse(body);
}

/**
 * Les composants de `/health`, en français. Un composant inconnu garde son
 * nom technique : mieux vaut un mot brut qu'une ligne qui disparaît.
 */
const COMPONENT_LABELS: Record<string, string> = {
  database: 'Base de données',
  redis: 'Cache (Redis)',
};

function StatusDot({ up }: { up: boolean }) {
  return (
    <span
      aria-hidden
      className={`inline-block h-2.5 w-2.5 rounded-full ${up ? 'bg-success' : 'bg-danger'}`}
    />
  );
}

/**
 * L'état de la plateforme, sur la page d'accueil PUBLIQUE (aucune connexion).
 *
 * Elle affichait `component.error` mot pour mot : pour une base arrêtée,
 * « Can't reach database server at `10.20.30.40:5432` », soit l'hôte et le
 * port internes, lisibles par n'importe qui. L'API ne publie plus ce détail
 * (il part à son journal) ; cette page ne l'affiche plus non plus, quoi que
 * le serveur envoie : en service ou indisponible, rien d'autre. Elle donnait
 * aussi, en production, la consigne de développement « lancez `pnpm dev:api`
 * et `docker compose up -d` ».
 */
export function ApiStatus() {
  const { data, isPending, isError } = useQuery({
    queryKey: ['api-health'],
    queryFn: fetchHealth,
    refetchInterval: 15_000,
  });

  if (isPending) {
    return <p className="text-sm text-muted">Vérification de l’API…</p>;
  }

  if (isError || data === undefined) {
    return (
      <p className="text-sm text-danger-ink" role="status">
        API injoignable pour le moment : l’état de la plateforme n’a pas pu être lu.
      </p>
    );
  }

  return (
    <ul className="flex flex-col gap-2 text-sm" role="status">
      <li className="flex items-center gap-2">
        <StatusDot up={data.status === 'ok'} />
        <span>API : {data.status === 'ok' ? 'opérationnelle' : 'dégradée'}</span>
      </li>
      {Object.entries(data.components).map(([name, component]) => (
        <li key={name} className="flex items-center gap-2">
          <StatusDot up={component.status === 'up'} />
          <span>
            {COMPONENT_LABELS[name] ?? name} :{' '}
            {component.status === 'up' ? 'en service' : 'indisponible'}
          </span>
        </li>
      ))}
    </ul>
  );
}
