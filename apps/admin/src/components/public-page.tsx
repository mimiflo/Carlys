import type { ReactNode } from 'react';

/** Surface des pages publiques : même carte que le reste de l'application. */
export function PublicCard({ children }: { children: ReactNode }) {
  return (
    <article className="animate-enter rounded-xl border border-border bg-surface p-6 sm:p-10">
      {children}
    </article>
  );
}

/** Page publique titrée : un titre, puis un contenu en colonne. */
export function PublicPage({ title, children }: { title: string; children: ReactNode }) {
  return (
    <PublicCard>
      <h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">{title}</h1>
      <div className="mt-6 flex flex-col gap-4 text-base leading-relaxed">{children}</div>
    </PublicCard>
  );
}

/**
 * Message d'issue d'une page publique. Le ton choisit le rôle ARIA : une
 * erreur interrompt (`alert`), un succès informe (`status`). Le succès garde
 * la couleur du texte courant, le vert seul ne contraste pas assez.
 */
export function PublicNotice({
  tone,
  children,
}: {
  tone: 'success' | 'error';
  children: ReactNode;
}) {
  if (tone === 'error') {
    return (
      <p
        role="alert"
        className="rounded-lg border border-danger/30 bg-danger/6 px-4 py-3 text-sm font-medium text-danger-ink"
      >
        {children}
      </p>
    );
  }
  return (
    <p
      role="status"
      className="flex items-start gap-3 rounded-lg bg-success/10 px-4 py-3 font-medium"
    >
      <span
        aria-hidden
        className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-success/25 text-xs text-foreground"
      >
        ✓
      </span>
      <span>{children}</span>
    </p>
  );
}
