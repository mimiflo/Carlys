import type { ReactNode } from 'react';

export type CarlysTheme = 'light' | 'dark' | 'oled';

export interface CarlysProviderProps {
  /** Thème appliqué à tout le sous-arbre (défaut : clair). */
  theme?: CarlysTheme;
  children: ReactNode;
  className?: string;
}

/**
 * Racine du design system : applique le fond, la typographie et les
 * variables de thème. Tout composant Carlys doit être rendu dessous —
 * sans elle, les surfaces et le texte n'ont pas leurs couleurs.
 */
export function CarlysProvider({ theme = 'light', children, className }: CarlysProviderProps) {
  const classes = ['carlys-root', className].filter(Boolean).join(' ');
  return (
    <div className={classes} data-carlys-theme={theme}>
      {children}
    </div>
  );
}
