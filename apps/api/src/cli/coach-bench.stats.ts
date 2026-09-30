/**
 * Mesures du banc de charge du coach (`coach-bench`) : fonctions pures, pour
 * que les chiffres annoncés au propriétaire soient testés, pas seulement
 * affichés.
 */

/** Ce qu'une demande simulée a vécu, vu du téléphone. */
export interface BenchSample {
  /** `done` reçu : réponse complète et archivée. */
  outcome: 'ok' | 'busy' | 'rate_limited' | 'timeout' | 'error';
  /** Millisecondes depuis l'envoi. `null` : jamais arrivé. */
  firstTokenMs: number | null;
  totalMs: number;
  /** Plus grand nombre d'attentes annoncé devant cette demande (`queued`). */
  maxAhead: number | null;
}

export interface LevelReport {
  users: number;
  ok: number;
  busy: number;
  rateLimited: number;
  timeouts: number;
  errors: number;
  /** Réponses complètes par seconde sur la durée du palier. */
  perSecond: number;
  ttftP50Ms: number | null;
  ttftP95Ms: number | null;
  totalP50Ms: number | null;
  totalP95Ms: number | null;
  /** File la plus longue observée : attentes devant + la demande elle-même. */
  maxQueue: number;
  wallMs: number;
}

/** Centile par rang le plus proche ; `null` sur une série vide. */
export function percentile(values: readonly number[], p: number): number | null {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const rank = Math.ceil((p / 100) * sorted.length);
  return sorted[Math.min(sorted.length, Math.max(rank, 1)) - 1] ?? null;
}

export function summarize(
  users: number,
  samples: readonly BenchSample[],
  wallMs: number,
): LevelReport {
  const ok = samples.filter((s) => s.outcome === 'ok');
  const count = (outcome: BenchSample['outcome']) =>
    samples.filter((s) => s.outcome === outcome).length;
  const ttft = ok.map((s) => s.firstTokenMs).filter((v): v is number => v !== null);
  const totals = ok.map((s) => s.totalMs);
  const aheads = samples.map((s) => s.maxAhead).filter((v): v is number => v !== null);
  return {
    users,
    ok: ok.length,
    busy: count('busy'),
    rateLimited: count('rate_limited'),
    timeouts: count('timeout'),
    errors: count('error'),
    perSecond: wallMs > 0 ? ok.length / (wallMs / 1000) : 0,
    ttftP50Ms: percentile(ttft, 50),
    ttftP95Ms: percentile(ttft, 95),
    totalP50Ms: percentile(totals, 50),
    totalP95Ms: percentile(totals, 95),
    maxQueue: aheads.length === 0 ? 0 : Math.max(...aheads) + 1,
    wallMs,
  };
}

const seconds = (ms: number | null) => (ms === null ? '—' : `${(ms / 1000).toFixed(1)} s`);

/** Le tableau Markdown des paliers, tel qu'il est remis au propriétaire. */
export function renderTable(reports: readonly LevelReport[]): string {
  const header =
    '| Utilisateurs simultanés | Réussies | Très sollicité | Rythme | Délai dépassé | Erreurs | Réponses/min | 1er mot p50 / p95 | Réponse p50 / p95 | File max | Durée du palier |';
  const rule = `|${' --- |'.repeat(11)}`;
  const rows = reports.map(
    (r) =>
      `| ${r.users} | ${r.ok} | ${r.busy} | ${r.rateLimited} | ${r.timeouts} | ${r.errors} | ${(r.perSecond * 60).toFixed(1)} | ${seconds(r.ttftP50Ms)} / ${seconds(r.ttftP95Ms)} | ${seconds(r.totalP50Ms)} / ${seconds(r.totalP95Ms)} | ${r.maxQueue} | ${seconds(r.wallMs)} |`,
  );
  return [header, rule, ...rows].join('\n');
}
