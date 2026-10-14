'use client';

import type { ReactNode } from 'react';
import { Card } from './card';
import { useCountUp } from './count-up';

const NUMBER = new Intl.NumberFormat('fr-FR');

/** Un chiffre clé : libellé, valeur qui monte, précision facultative. */
export function Stat({
  label,
  value,
  hint,
  icon,
}: {
  label: string;
  value: number;
  hint?: ReactNode;
  icon?: ReactNode;
}) {
  const shown = useCountUp(value);
  return (
    <Card className="p-4 sm:p-5">
      <div className="flex items-center justify-between gap-3">
        <p className="text-sm font-medium text-muted">{label}</p>
        {icon !== undefined && (
          <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10 text-primary-ink">
            {icon}
          </span>
        )}
      </div>
      <p className="tabular-nums mt-3 text-2xl font-semibold sm:text-3xl tracking-tight">
        {shown === value ? (
          NUMBER.format(value)
        ) : (
          <>
            <span aria-hidden>{NUMBER.format(shown)}</span>
            <span className="sr-only">{NUMBER.format(value)}</span>
          </>
        )}
      </p>
      {hint !== undefined && <p className="mt-1 text-xs text-muted">{hint}</p>}
    </Card>
  );
}
