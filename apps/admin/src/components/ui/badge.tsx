import type { StatusLabel, StatusTone } from '@/lib/status-labels';

/**
 * La pastille de statut : un point de couleur ET le libellé, toujours les
 * deux. Le texte reste en encre pleine sur un fond à peine teinté — la
 * couleur dit la famille, le mot dit le statut (jamais la couleur seule).
 */
const TONES: Record<StatusTone, { dot: string; fill: string; halo: string }> = {
  success: { dot: 'bg-success', fill: 'bg-success/12', halo: 'text-success' },
  warning: { dot: 'bg-warning', fill: 'bg-warning/15', halo: 'text-warning' },
  danger: { dot: 'bg-danger', fill: 'bg-danger/12', halo: 'text-danger-ink' },
  neutral: { dot: 'bg-muted', fill: 'bg-foreground/6', halo: 'text-muted' },
  primary: { dot: 'bg-primary', fill: 'bg-primary/12', halo: 'text-primary-ink' },
  info: { dot: 'bg-info', fill: 'bg-info/12', halo: 'text-info' },
};

export function Badge({ status, live = false }: { status: StatusLabel; live?: boolean }) {
  const tone = TONES[status.tone];
  return (
    <span
      className={`inline-flex h-6 items-center gap-1.5 whitespace-nowrap rounded-full px-2.5 text-xs font-medium text-foreground ${tone.fill}`}
    >
      <span aria-hidden className={`relative inline-block h-1.5 w-1.5 rounded-full ${tone.dot}`}>
        {live && (
          <span className={`animate-halo absolute inset-0 rounded-full ${tone.dot} ${tone.halo}`} />
        )}
      </span>
      {status.label}
    </span>
  );
}
