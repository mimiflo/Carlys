import type { ReactNode } from 'react';
import { Card } from './card';

/**
 * Les tableaux du back-office : des en-têtes discrets, des lignes de 52 px
 * qui s'éclairent au survol ; au téléphone, une carte par ligne
 * (`.table-stack`, dans globals.css — une cellule y nomme sa colonne par
 * `data-label`). Les classes `th`/`td` restent des chaînes : les cellules gardent
 * leurs balises natives, et les tests leurs rôles.
 */
export function TableCard({ children }: { children: ReactNode }) {
  return (
    <Card className="overflow-hidden">
      <div className="md:overflow-x-auto">
        <table className="table-stack w-full text-left text-sm">{children}</table>
      </div>
    </Card>
  );
}

export const thead = 'border-b border-border bg-surface-alt/60 text-xs font-medium text-muted';
export const th = 'px-4 py-3 font-medium whitespace-nowrap';
export const tr =
  'border-b border-border transition-colors duration-150 last:border-0 hover:bg-primary/[0.03]';
export const td = 'px-4 py-3.5 align-middle';
