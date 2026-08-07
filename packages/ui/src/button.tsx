import type { ButtonHTMLAttributes, ReactNode } from 'react';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'destructive';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  /** Style du bouton (défaut : primary). */
  variant?: ButtonVariant;
  /** Taille (défaut : md, hauteur 44px). */
  size?: ButtonSize;
  /** Icône optionnelle rendue avant le libellé. */
  icon?: ReactNode;
  /** Affiche un indicateur et désactive le bouton. */
  isLoading?: boolean;
  /** Occupe toute la largeur disponible. */
  isExpanded?: boolean;
}

/** Bouton Carlys — mêmes variantes que l'AppButton Flutter. */
export function Button({
  variant = 'primary',
  size = 'md',
  icon,
  isLoading = false,
  isExpanded = false,
  disabled,
  className,
  children,
  type = 'button',
  ...rest
}: ButtonProps) {
  const classes = [
    'carlys-button',
    `carlys-button--${variant}`,
    `carlys-button--${size}`,
    isExpanded ? 'carlys-button--expanded' : null,
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <button type={type} className={classes} disabled={disabled === true || isLoading} {...rest}>
      {isLoading ? (
        <span className="carlys-spinner" aria-hidden />
      ) : (
        icon != null && <span aria-hidden>{icon}</span>
      )}
      {children}
    </button>
  );
}
