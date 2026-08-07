export interface LoadingIndicatorProps {
  /** Texte affiché sous l'indicateur (ex. « Chargement »). */
  label?: string;
  className?: string;
}

/** Indicateur de chargement centré, avec libellé optionnel. */
export function LoadingIndicator({ label, className }: LoadingIndicatorProps) {
  const classes = ['carlys-state', className].filter(Boolean).join(' ');
  return (
    <div className={classes} role="status" aria-live="polite">
      <span className="carlys-spinner" aria-hidden />
      {label != null && <p className="carlys-state__message">{label}</p>}
    </div>
  );
}
