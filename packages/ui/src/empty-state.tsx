import type { ReactNode } from 'react';

export interface EmptyStateProps {
  /** Titre court de l'état vide. */
  title: string;
  /** Explication ou prochaine action suggérée. */
  message?: string;
  /** Icône décorative au-dessus du titre. */
  icon?: ReactNode;
  /** Action optionnelle (typiquement un `Button`). */
  action?: ReactNode;
  className?: string;
}

/** État vide standard : icône, titre, message, action éventuelle. */
export function EmptyState({ title, message, icon, action, className }: EmptyStateProps) {
  const classes = ['carlys-state', className].filter(Boolean).join(' ');
  return (
    <div className={classes}>
      {icon != null && (
        <span className="carlys-state__icon" aria-hidden>
          {icon}
        </span>
      )}
      <h3 className="carlys-state__title">{title}</h3>
      {message != null && <p className="carlys-state__message">{message}</p>}
      {action != null && <div className="carlys-state__action">{action}</div>}
    </div>
  );
}
