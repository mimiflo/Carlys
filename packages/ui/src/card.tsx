import type { ReactNode } from 'react';

export interface CardProps {
  children: ReactNode;
  /** Rend la carte cliquable (élément `button`, ombre au survol). */
  onClick?: () => void;
  className?: string;
  /** Libellé accessible quand la carte est cliquable. */
  'aria-label'?: string;
}

/** Surface standard Carlys : fond, bordure fine, rayon large. */
export function Card({ children, onClick, className, 'aria-label': ariaLabel }: CardProps) {
  const classes = ['carlys-card', className].filter(Boolean).join(' ');

  if (onClick) {
    return (
      <button type="button" className={classes} onClick={onClick} aria-label={ariaLabel}>
        {children}
      </button>
    );
  }
  return <div className={classes}>{children}</div>;
}
