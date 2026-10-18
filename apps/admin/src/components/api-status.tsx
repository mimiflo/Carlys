'use client';

import { useQuery } from '@tanstack/react-query';
// `zod/mini` et non le contrat `healthReportSchema` (Zod classique) : ce
// composant est sur l'accueil PUBLIC, qui n'a pas à charger Zod complet pour
// trois champs. Seuls les champs AFFICHÉS sont lus ; `error`, que la page ne
// montre jamais, n'est pas même gardé.
import * as z from 'zod/mini';
import { publicEnv } from '@/lib/env';
import { DEGRADED, healthStatus, type StatusLabel } from '@/lib/status-labels';
import { Badge } from './ui/badge';

const healthReportSchema = z.object({
  status: z.enum(['ok', 'error']),
  uptimeSeconds: z.number(),
  components: z.record(z.string(), z.object({ status: z.enum(['up', 'down']) })),
});

export type HealthReport = z.infer<typeof healthReportSchema>;

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

/** « 3 j 4 h », « 5 h 12 min », « 40 min » : la durée lisible d'un coup d'œil. */
export function uptimeLabel(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  if (days > 0) return `${days} j ${hours % 24} h`;
  if (hours > 0) return `${hours} h ${minutes % 60} min`;
  return `${minutes} min`;
}

function Row({ label, status }: { label: string; status: StatusLabel }) {
  return (
    <li className="flex items-center justify-between gap-4 py-3">
      <span className="text-sm font-medium">{label}</span>
      <Badge status={status} live={status.tone === 'success'} />
    </li>
  );
}

/**
 * L'état de la plateforme, sur la page d'accueil PUBLIQUE (aucune connexion)
 * et dans la vue d'ensemble.
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
  const { data, isPending, isError, dataUpdatedAt } = useQuery({
    queryKey: ['api-health'],
    queryFn: fetchHealth,
    refetchInterval: 15_000,
  });

  if (isPending) {
    return (
      // À la forme du contenu (bandeau, puis l'API et chaque composant
      // connu) : l'arrivée de la réponse ne fait rien sauter.
      <div aria-busy="true">
        <span className="sr-only">Vérification de l’API…</span>
        <div className="animate-skeleton h-11 rounded-lg bg-foreground/6" />
        <ul aria-hidden className="mt-2 divide-y divide-border">
          {['API', ...Object.keys(COMPONENT_LABELS)].map((name) => (
            <li key={name} className="flex items-center justify-between gap-4 py-3">
              <span className="animate-skeleton h-4 w-32 rounded bg-foreground/6" />
              <span className="animate-skeleton h-6 w-24 rounded-full bg-foreground/6" />
            </li>
          ))}
        </ul>
      </div>
    );
  }

  if (isError || data === undefined) {
    return (
      <div role="status" className="flex items-center justify-between gap-4">
        <p className="text-sm text-danger-ink">
          API injoignable pour le moment : l’état de la plateforme n’a pas pu être lu.
        </p>
        <Badge status={healthStatus(false)} />
      </div>
    );
  }

  const allUp =
    data.status === 'ok' && Object.values(data.components).every((c) => c.status === 'up');

  // La zone annoncée aux lecteurs d'écran ne porte que la SYNTHÈSE : elle ne
  // change que si un statut change. L'heure de vérification, relue toutes
  // les 15 s, reste hors de la zone — sinon tout le bloc serait relu à
  // chaque fois.
  return (
    <div>
      <div
        className={`flex flex-wrap items-center justify-between gap-3 rounded-lg px-4 py-3 ${
          allUp ? 'bg-success/10' : 'bg-warning/15'
        }`}
      >
        <p role="status" className="text-sm font-semibold">
          {allUp ? 'Tous les services sont opérationnels' : 'Service dégradé'}
        </p>
        <p className="tabular-nums text-xs text-muted">
          En ligne depuis {uptimeLabel(data.uptimeSeconds)} · vérifié à{' '}
          {new Date(dataUpdatedAt).toLocaleTimeString('fr-FR')}
        </p>
      </div>
      <ul className="mt-2 divide-y divide-border">
        <Row label="API" status={data.status === 'ok' ? healthStatus(true) : DEGRADED} />
        {Object.entries(data.components).map(([name, component]) => (
          <Row
            key={name}
            label={COMPONENT_LABELS[name] ?? name}
            status={healthStatus(component.status === 'up')}
          />
        ))}
      </ul>
    </div>
  );
}
