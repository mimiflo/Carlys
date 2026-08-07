export interface MetricProps {
  /** Valeur mise en avant (ex. « 2759 kcal », « 82,5 kg »). */
  value: string;
  /** Libellé sous la valeur. */
  label: string;
  /** `lg` : valeur en très grand, couleur primaire (métrique héro). */
  size?: 'md' | 'lg';
  className?: string;
}

/** Chiffre clé avec libellé — l'équivalent des cartes de stats mobiles. */
export function Metric({ value, label, size = 'md', className }: MetricProps) {
  const classes = ['carlys-metric', size === 'lg' ? 'carlys-metric--lg' : null, className]
    .filter(Boolean)
    .join(' ');

  return (
    <div className={classes} role="group" aria-label={`${label} : ${value}`}>
      <div className="carlys-metric__value">{value}</div>
      <div className="carlys-metric__label">{label}</div>
    </div>
  );
}
