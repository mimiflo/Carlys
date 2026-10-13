/**
 * Les classes des boutons, en fonction plutôt qu'en composant : un `<button>`,
 * un `<Link>` ou un `<label>` de téléversement prennent la même apparence sans
 * qu'un composant enveloppe ne leur retire leurs attributs natifs.
 */
type Variant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'danger-outline';
type Size = 'sm' | 'md';

const BASE =
  'inline-flex items-center justify-center gap-2 rounded-lg font-semibold whitespace-nowrap transition-[background-color,color,border-color,box-shadow,transform] duration-150 ease-out active:scale-[0.98] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:pointer-events-none disabled:opacity-50';

const VARIANTS: Record<Variant, string> = {
  primary: 'bg-primary text-white shadow-sm hover:bg-primary-dark',
  secondary:
    'border border-border bg-surface text-foreground hover:border-primary/40 hover:bg-primary/5',
  ghost: 'text-primary-ink hover:bg-primary/10',
  danger: 'bg-danger-strong text-white shadow-sm hover:bg-danger-strong/90',
  'danger-outline': 'border border-danger/40 bg-surface text-danger-ink hover:bg-danger/6',
};

const SIZES: Record<Size, string> = {
  sm: 'h-8 px-3 text-xs',
  md: 'h-9 px-4 text-sm',
};

export function button(variant: Variant = 'primary', size: Size = 'md'): string {
  return `${BASE} ${VARIANTS[variant]} ${SIZES[size]}`;
}

/** Champ de saisie : 40 px, anneau violet au focus. */
export const field =
  'h-10 w-full rounded-lg border border-border bg-surface px-3 text-sm text-foreground transition-[border-color,box-shadow] duration-150 ease-out hover:border-foreground/25 focus-visible:border-primary focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-primary/15';

/** Zone de texte : le champ, sans hauteur fixe. */
export const textarea = field.replace('h-10 ', '').concat(' py-2');
