'use client';

import Link from 'next/link';
import type { ComponentType, SVGProps } from 'react';
import {
  DumbbellIcon,
  FlagIcon,
  ImageIcon,
  OverviewIcon,
  ScrollIcon,
  TagIcon,
  UsersIcon,
} from './ui/icons';

/**
 * Chaque entrée porte la permission que sa page EXIGE — la même que le
 * contrôleur correspondant déclare par `@RequirePermissions`.
 *
 * La liste était inconditionnelle : un administrateur « content-manager »,
 * qui n'a ni `user:read` ni `audit:read` ni `community:moderate`, voyait les
 * six entrées, atterrissait sur « Utilisateurs » et n'y trouvait qu'un
 * message d'erreur lui conseillant de se reconnecter — ce qui n'y changeait
 * rien, puisque c'est son rôle et non sa session.
 *
 * Le contrôle d'ACCÈS, lui, reste entièrement côté serveur : masquer une
 * entrée n'interdit rien, cela évite seulement de proposer une porte qu'on
 * sait fermée. La vue d'ensemble exige `user:read`, comme ses chiffres clés
 * (`GET /admin/overview`).
 */
export const NAV_ITEMS: ReadonlyArray<{
  href: string;
  label: string;
  permission: string;
  icon: ComponentType<SVGProps<SVGSVGElement>>;
}> = [
  { href: '/overview', label: 'Vue d’ensemble', permission: 'user:read', icon: OverviewIcon },
  { href: '/users', label: 'Utilisateurs', permission: 'user:read', icon: UsersIcon },
  { href: '/reports', label: 'Signalements', permission: 'community:moderate', icon: FlagIcon },
  { href: '/exercises', label: 'Exercices', permission: 'exercise:read', icon: DumbbellIcon },
  { href: '/categories', label: 'Catégories', permission: 'exercise:read', icon: TagIcon },
  { href: '/media', label: 'Médias', permission: 'media:read', icon: ImageIcon },
  { href: '/audit', label: 'Journal d’audit', permission: 'audit:read', icon: ScrollIcon },
];

/**
 * La première page qu'un administrateur peut RÉELLEMENT ouvrir.
 *
 * `/users` était l'accueil pour tout le monde, y compris pour ceux qui n'ont
 * pas le droit de la lire.
 */
export function firstAllowedRoute(permissions: readonly string[]): string {
  return NAV_ITEMS.find((item) => permissions.includes(item.permission))?.href ?? '/users';
}

/** Les entrées autorisées ; l'active porte une pastille violette et `aria-current`. */
export function AdminNav({
  permissions,
  pathname,
}: {
  permissions: readonly string[];
  pathname: string;
}) {
  return (
    <nav aria-label="Navigation d’administration" className="flex flex-col gap-0.5">
      {NAV_ITEMS.filter((item) => permissions.includes(item.permission)).map((item) => {
        const active = pathname.startsWith(item.href);
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href}
            aria-current={active ? 'page' : undefined}
            className={`group flex h-9 items-center gap-3 rounded-lg px-3 text-sm font-medium transition-colors duration-150 focus-visible:outline-2 focus-visible:outline-primary ${
              active
                ? 'bg-primary/12 text-primary-ink'
                : 'text-muted hover:bg-foreground/5 hover:text-foreground'
            }`}
          >
            <Icon
              className={`shrink-0 transition-transform duration-150 group-hover:scale-110 ${active ? '' : 'opacity-80'}`}
            />
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
