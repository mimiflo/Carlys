import type { ReactNode } from 'react';
import { button } from './button';
import { AlertIcon, InboxIcon, RefreshIcon } from './icons';

/**
 * Les états d'une liste : chargement (squelette aux dimensions du contenu),
 * vide (une phrase qui dit pourquoi), erreur (le message ET de quoi réessayer).
 */
export function SkeletonRows({
  rows = 6,
  label = 'Chargement…',
}: {
  rows?: number;
  label?: string;
}) {
  return (
    <div aria-busy="true" className="animate-fade flex flex-col gap-2">
      <span className="sr-only">{label}</span>
      {Array.from({ length: rows }, (_, index) => (
        <div key={index} className="animate-skeleton h-12 rounded-lg bg-foreground/6" />
      ))}
    </div>
  );
}

export function EmptyState({ children, icon }: { children: ReactNode; icon?: ReactNode }) {
  return (
    <div className="animate-fade flex flex-col items-center gap-3 px-6 py-12 text-center">
      <span className="flex h-11 w-11 items-center justify-center rounded-full bg-primary/10 text-primary-ink">
        {icon ?? <InboxIcon />}
      </span>
      <p className="max-w-sm text-sm text-muted">{children}</p>
    </div>
  );
}

export function ErrorState({ children, onRetry }: { children: ReactNode; onRetry?: () => void }) {
  return (
    <div
      role="alert"
      className="animate-enter flex flex-wrap items-center gap-3 rounded-xl border border-danger/30 bg-danger/6 px-4 py-3 text-sm"
    >
      <span className="text-danger-ink">
        <AlertIcon />
      </span>
      <p className="flex-1 font-medium text-danger-ink">{children}</p>
      {onRetry !== undefined && (
        <button type="button" onClick={onRetry} className={button('secondary', 'sm')}>
          <RefreshIcon width={14} height={14} />
          Réessayer
        </button>
      )}
    </div>
  );
}
