import type { ReactNode, SVGProps } from 'react';

/**
 * Les icônes du back-office : des tracés maison, au trait, en `currentColor`.
 *
 * Aucune bibliothèque : une dizaine de pictogrammes ne justifie pas une
 * dépendance, et un tracé inline suit la couleur du texte qui l'entoure, donc
 * le thème. Toujours `aria-hidden` : le libellé voisin porte le sens, une
 * icône seule ne dit jamais rien à un lecteur d'écran.
 */
function Icon({ children, ...props }: SVGProps<SVGSVGElement> & { children: ReactNode }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={18}
      height={18}
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
      focusable="false"
      {...props}
    >
      {children}
    </svg>
  );
}

type P = SVGProps<SVGSVGElement>;

export const OverviewIcon = (p: P) => (
  <Icon {...p}>
    <rect x="3" y="3" width="7" height="9" rx="1.5" />
    <rect x="14" y="3" width="7" height="5" rx="1.5" />
    <rect x="14" y="12" width="7" height="9" rx="1.5" />
    <rect x="3" y="16" width="7" height="5" rx="1.5" />
  </Icon>
);

export const UsersIcon = (p: P) => (
  <Icon {...p}>
    <circle cx="9" cy="8" r="3.5" />
    <path d="M2.5 20a6.5 6.5 0 0 1 13 0" />
    <path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 14.2A6.5 6.5 0 0 1 21.5 20" />
  </Icon>
);

export const FlagIcon = (p: P) => (
  <Icon {...p}>
    <path d="M5 21V4" />
    <path d="M5 4h11l-2 4 2 4H5" />
  </Icon>
);

export const DumbbellIcon = (p: P) => (
  <Icon {...p}>
    <path d="M6.5 6.5v11M17.5 6.5v11M3.5 9v6M20.5 9v6M6.5 12h11" />
  </Icon>
);

export const TagIcon = (p: P) => (
  <Icon {...p}>
    <path d="M3 12V4a1 1 0 0 1 1-1h8l9 9-9 9z" />
    <circle cx="8" cy="8" r="1.5" />
  </Icon>
);

export const ImageIcon = (p: P) => (
  <Icon {...p}>
    <rect x="3" y="4" width="18" height="16" rx="2" />
    <circle cx="9" cy="10" r="2" />
    <path d="m21 16-5-5L5 20" />
  </Icon>
);

export const ScrollIcon = (p: P) => (
  <Icon {...p}>
    <path d="M8 3h11a2 2 0 0 1 2 2v12" />
    <path d="M16 21H6a3 3 0 0 1-3-3v-1h13v1a3 3 0 0 0 6 0" />
    <path d="M8 3a2 2 0 0 0-2 2v12M10 8h6M10 12h6" />
  </Icon>
);

export const LogoutIcon = (p: P) => (
  <Icon {...p}>
    <path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3" />
    <path d="M10 17l-5-5 5-5M5 12h11" />
  </Icon>
);

export const SearchIcon = (p: P) => (
  <Icon {...p}>
    <circle cx="11" cy="11" r="6.5" />
    <path d="m20 20-4.2-4.2" />
  </Icon>
);

export const MenuIcon = (p: P) => (
  <Icon {...p}>
    <path d="M4 7h16M4 12h16M4 17h16" />
  </Icon>
);

export const CloseIcon = (p: P) => (
  <Icon {...p}>
    <path d="M6 6l12 12M18 6 6 18" />
  </Icon>
);

export const ArrowLeftIcon = (p: P) => (
  <Icon {...p}>
    <path d="M19 12H5M11 18l-6-6 6-6" />
  </Icon>
);

export const ArrowRightIcon = (p: P) => (
  <Icon {...p}>
    <path d="M5 12h14M13 6l6 6-6 6" />
  </Icon>
);

export const ShieldIcon = (p: P) => (
  <Icon {...p}>
    <path d="M12 3 4.5 6v5.5c0 4.6 3.2 8.3 7.5 9.5 4.3-1.2 7.5-4.9 7.5-9.5V6z" />
    <path d="m9 12 2 2 4-4" />
  </Icon>
);

export const AlertIcon = (p: P) => (
  <Icon {...p}>
    <path d="M12 4 2.8 19.5h18.4z" />
    <path d="M12 10v4M12 17h.01" />
  </Icon>
);

export const InboxIcon = (p: P) => (
  <Icon {...p}>
    <path d="M3 13l2.5-8h13L21 13v6a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z" />
    <path d="M3 13h5l1.5 3h5L16 13h5" />
  </Icon>
);

export const RefreshIcon = (p: P) => (
  <Icon {...p}>
    <path d="M20 11a8 8 0 0 0-14.3-4.5L4 8M4 4v4h4" />
    <path d="M4 13a8 8 0 0 0 14.3 4.5L20 16M20 20v-4h-4" />
  </Icon>
);

export const UploadIcon = (p: P) => (
  <Icon {...p}>
    <path d="M12 16V4M7 9l5-5 5 5" />
    <path d="M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3" />
  </Icon>
);

export const SparkIcon = (p: P) => (
  <Icon {...p}>
    <path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M18 6l-2.5 2.5M8.5 15.5 6 18" />
  </Icon>
);

export const CheckCircleIcon = (p: P) => (
  <Icon {...p}>
    <circle cx="12" cy="12" r="9" />
    <path d="m8 12.5 2.5 2.5L16 9.5" />
  </Icon>
);

/**
 * Le VRAI logo Carlys : le C facetté de l'application
 * (`apps/mobile/assets/brand/carlys-mark.webp`), recadré et réduit à 120 px
 * de haut dans `public/brand/` (net jusqu'à 40 px en densité ×3, 6 Ko).
 * Décoratif : le nom « Carlys » est toujours écrit à côté.
 */
export function CarlysMark({ className = 'h-7' }: { className?: string }) {
  return (
    // eslint-disable-next-line @next/next/no-img-element -- fichier statique de 6 Ko, rien à optimiser
    <img
      src="/brand/carlys-mark.webp"
      alt=""
      aria-hidden
      width={150}
      height={120}
      className={`w-auto shrink-0 ${className}`}
    />
  );
}
