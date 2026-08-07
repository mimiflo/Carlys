import { Button } from './button.js';

export interface ErrorStateProps {
  /** Titre de l'erreur (ex. « Statistiques indisponibles »). */
  title: string;
  /** Explication orientée solution. */
  message?: string;
  /** Affiche un bouton « Réessayer » qui déclenche ce rappel. */
  onRetry?: () => void;
  className?: string;
}

/** État d'erreur standard, avec relance optionnelle. */
export function ErrorState({ title, message, onRetry, className }: ErrorStateProps) {
  const classes = ['carlys-state', 'carlys-state--error', className].filter(Boolean).join(' ');
  return (
    <div className={classes} role="alert">
      <span className="carlys-state__icon" aria-hidden>
        <svg width="32" height="32" viewBox="0 0 24 24" fill="none">
          <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" />
          <path
            d="M12 7.5v5.5m0 3.5v.01"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
          />
        </svg>
      </span>
      <h3 className="carlys-state__title">{title}</h3>
      {message != null && <p className="carlys-state__message">{message}</p>}
      {onRetry != null && (
        <div className="carlys-state__action">
          <Button variant="secondary" onClick={onRetry}>
            Réessayer
          </Button>
        </div>
      )}
    </div>
  );
}
