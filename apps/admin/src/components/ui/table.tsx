import type { ReactNode } from 'react';
import { Card } from './card';

/**
 * Les tableaux du back-office : une carte qui défile en largeur sur
 * téléphone, des en-têtes discrets, des lignes de 52 px qui s'éclairent au
 * survol. Les classes `th`/`td` restent des chaînes : les cellules gardent
 * leurs balises natives, et les tests leurs rôles.
 */
export function TableCard({ children }: { children: ReactNode }) {
  return (
    <Card className="overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full text-left text-sm">{children}</table>
      </div>
    </Card>
  );
}

export const thead = 'border-b border-border bg-surface-alt/60 text-xs font-medium text-muted';
export const th = 'px-4 py-3 font-medium whitespace-nowrap';
export const tr =
  'border-b border-border transition-colors duration-150 last:border-0 hover:bg-primary/[0.03]';
export const td = 'px-4 py-3.5 align-middle';
