import type { ReactNode } from 'react';

/** Surface des pages publiques : même carte que le reste de l'application. */
export function PublicCard({ children }: { children: ReactNode }) {
  return (
    <article className="rounded-2xl bg-surface p-8 shadow-sm ring-1 ring-black/5">
      {children}
    </article>
  );
}

/** Page publique titrée : un titre, puis un contenu en colonne. */
export function PublicPage({ title, children }: { title: string; children: ReactNode }) {
  return (
    <PublicCard>
      <h1 className="text-2xl font-bold tracking-tight">{title}</h1>
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
      <p role="alert" className="text-sm font-medium text-danger">
        {children}
      </p>
    );
  }
  return (
    <p role="status" className="flex items-start gap-2 font-medium">
      <span aria-hidden className="text-success">
        ✓
      </span>
      <span>{children}</span>
    </p>
  );
}
