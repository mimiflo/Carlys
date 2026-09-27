'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useSyncExternalStore, type ReactNode } from 'react';
import { adminToken } from '@/lib/admin-api';
import { useAdminPermissions } from './use-admin-permissions';

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
 * sait fermée.
 */
const NAV_ITEMS = [
  { href: '/users', label: 'Utilisateurs', permission: 'user:read' },
  { href: '/reports', label: 'Signalements', permission: 'community:moderate' },
  { href: '/exercises', label: 'Exercices', permission: 'exercise:read' },
  { href: '/categories', label: 'Catégories', permission: 'exercise:read' },
  { href: '/media', label: 'Médias', permission: 'media:read' },
  { href: '/audit', label: 'Journal d’audit', permission: 'audit:read' },
] as const;

/**
 * La première page qu'un administrateur peut RÉELLEMENT ouvrir.
 *
 * `/users` était l'accueil pour tout le monde, y compris pour ceux qui n'ont
 * pas le droit de la lire.
 */
export function firstAllowedRoute(permissions: readonly string[]): string {
  return NAV_ITEMS.find((item) => permissions.includes(item.permission))?.href ?? '/users';
}

/**
 * Coquille des pages du back-office : barre de navigation, déconnexion et
 * garde de session côté client (redirection immédiate vers /login sans
 * jeton — le VRAI contrôle d'accès reste côté serveur, sur chaque requête).
 *
 * Le jeton est ÉCOUTÉ, pas seulement lu au montage : quand une requête
 * revient en 401 (jeton expiré, compte désactivé), le client l'oublie
 * (`adminToken.expire`), la coquille bascule et renvoie vers la connexion,
 * quelle que soit la page ouverte.
 */
export function AdminShell({ title, children }: { title: string; children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  // Jeton lu hors rendu serveur (instantané serveur : null → rien n'est
  // affiché avant l'hydratation, puis redirection si non connecté).
  const token = useSyncExternalStore(adminToken.subscribe, adminToken.get, () => null);
  const permissions = useAdminPermissions();

  useEffect(() => {
    // Le STOCKAGE décide, pas la valeur rendue. Au chargement d'une page
    // (rechargement, lien ouvert dans un nouvel onglet), l'hydratation rend
    // l'instantané serveur, `null`, et cet effet s'exécute avant le rendu
    // qui lit le vrai jeton : il renvoyait vers /login un administrateur
    // bel et bien connecté, à chaque rechargement.
    if (token === null && adminToken.get() === null) {
      router.replace('/login');
    }
  }, [token, router]);

  if (token === null) {
    return null;
  }

  return (
    <div className="flex min-h-full flex-1 flex-col">
      <header className="border-b border-black/5 bg-surface">
        <div className="mx-auto flex w-full max-w-5xl items-center gap-6 px-6 py-4">
          {/* Le logo ramenait lui aussi à /users, quelles que soient les
              permissions : il suit la même règle que la redirection après
              connexion. */}
          <Link
            href={firstAllowedRoute(permissions)}
            className="text-sm font-bold uppercase tracking-widest text-primary-ink"
          >
            Carlys Admin
          </Link>
          <nav aria-label="Navigation d’administration" className="flex gap-4">
            {NAV_ITEMS.filter((item) => permissions.includes(item.permission)).map((item) => (
              <Link
                key={item.href}
                href={item.href}
                aria-current={pathname.startsWith(item.href) ? 'page' : undefined}
                className={`text-sm font-medium transition-colors hover:text-primary-ink ${
                  pathname.startsWith(item.href) ? 'text-primary-ink' : 'text-muted'
                }`}
              >
                {item.label}
              </Link>
            ))}
          </nav>
          <button
            type="button"
            onClick={() => {
              adminToken.clear();
              router.replace('/login');
            }}
            className="ml-auto text-sm font-medium text-muted transition-colors hover:text-danger-ink"
          >
            Se déconnecter
          </button>
        </div>
      </header>
      <main className="mx-auto w-full max-w-5xl flex-1 px-6 py-8">
        <h1 className="text-2xl font-bold tracking-tight">{title}</h1>
        <div className="mt-6">{children}</div>
      </main>
    </div>
  );
}
