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

function StatusDot({ up }: { up: boolean }) {
  return (
    <span
      aria-hidden
      className={`inline-block h-2.5 w-2.5 rounded-full ${up ? 'bg-success' : 'bg-danger'}`}
    />
  );
}

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
      <p className="text-sm text-danger" role="status">
        API injoignable : vérifiez que `pnpm dev:api` et `docker compose up -d` sont lancés.
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
            {name} : {component.status === 'up' ? 'connecté' : (component.error ?? 'indisponible')}
          </span>
        </li>
      ))}
    </ul>
  );
}
