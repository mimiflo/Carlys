import type { ReactNode } from 'react';

/** Une surface : fond carte, filet fin, rayon 12, entrée en fondu. */
export function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <div className={`animate-enter rounded-xl border border-border bg-surface ${className}`}>
      {children}
    </div>
  );
}

/** Une section titrée d'une page (fiche utilisateur, panneaux d'action). */
export function Section({
  title,
  description,
  actions,
  children,
}: {
  title: string;
  description?: ReactNode;
  actions?: ReactNode;
  children: ReactNode;
}) {
  return (
    <Card className="p-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-base font-semibold">{title}</h2>
          {description !== undefined && <p className="mt-1 text-sm text-muted">{description}</p>}
        </div>
        {actions}
      </div>
      <div className="mt-5">{children}</div>
    </Card>
  );
}
