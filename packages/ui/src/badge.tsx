import type { ReactNode } from 'react';

export type BadgeVariant = 'neutral' | 'primary' | 'accent' | 'warning';

export interface BadgeProps {
  children: ReactNode;
  /** Ton de la pastille (défaut : neutral). */
  variant?: BadgeVariant;
  /** Icône optionnelle avant le texte. */
  icon?: ReactNode;
  className?: string;
}

/** Pastille d'information courte (difficulté, statut, Premium…). */
export function Badge({ children, variant = 'neutral', icon, className }: BadgeProps) {
  const classes = ['carlys-badge', `carlys-badge--${variant}`, className].filter(Boolean).join(' ');

  return (
    <span className={classes}>
      {icon != null && <span aria-hidden>{icon}</span>}
      {children}
    </span>
  );
}
