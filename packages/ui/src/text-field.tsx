import type { InputHTMLAttributes } from 'react';
import { useId } from 'react';

export interface TextFieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'id'> {
  /** Libellé affiché au-dessus du champ. */
  label: string;
  /** Aide affichée sous le champ (masquée si `error` est présent). */
  hint?: string;
  /** Message d'erreur — passe le champ en état d'erreur. */
  error?: string;
}

/** Champ de saisie standard Carlys : libellé, aide et erreur intégrés. */
export function TextField({ label, hint, error, className, ...rest }: TextFieldProps) {
  const id = useId();
  const describedBy = error != null ? `${id}-error` : hint != null ? `${id}-hint` : undefined;
  const classes = ['carlys-field', error != null ? 'carlys-field--error' : null, className]
    .filter(Boolean)
    .join(' ');

  return (
    <div className={classes}>
      <label className="carlys-field__label" htmlFor={id}>
        {label}
      </label>
      <input
        id={id}
        className="carlys-field__input"
        aria-invalid={error != null || undefined}
        aria-describedby={describedBy}
        {...rest}
      />
      {error != null ? (
        <span id={`${id}-error`} className="carlys-field__error" role="alert">
          {error}
        </span>
      ) : (
        hint != null && (
          <span id={`${id}-hint`} className="carlys-field__hint">
            {hint}
          </span>
        )
      )}
    </div>
  );
}
