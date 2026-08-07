import type { InputHTMLAttributes } from 'react';

export interface SearchFieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> {
  /** Libellé accessible du champ (défaut : « Rechercher »). */
  'aria-label'?: string;
}

/** Champ de recherche compact (bibliothèque d'exercices, listes admin). */
export function SearchField({
  className,
  'aria-label': ariaLabel = 'Rechercher',
  placeholder = 'Rechercher…',
  ...rest
}: SearchFieldProps) {
  const classes = ['carlys-field', className].filter(Boolean).join(' ');
  return (
    <div className={classes}>
      <input
        type="search"
        className="carlys-field__input"
        aria-label={ariaLabel}
        placeholder={placeholder}
        {...rest}
      />
    </div>
  );
}
