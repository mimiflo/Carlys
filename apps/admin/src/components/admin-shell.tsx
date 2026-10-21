'use client';

import { useQueryClient } from '@tanstack/react-query';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useRef, useState, useSyncExternalStore, type ReactNode } from 'react';
import { adminApi, adminToken } from '@/lib/admin-api';
import { AdminNav, firstAllowedRoute } from './admin-nav';
import { CarlysMark, CloseIcon, LogoutIcon, MenuIcon } from './ui/icons';
import { useAdminPermissions } from './use-admin-permissions';

/**
 * Coquille des pages du back-office : barre latérale (tiroir sur
 * téléphone), en-tête de page, déconnexion et garde de session côté client
 * (redirection immédiate vers /login sans jeton — le VRAI contrôle d'accès
 * reste côté serveur, sur chaque requête).
 *
 * Le jeton est ÉCOUTÉ, pas seulement lu au montage : quand une requête
 * revient en 401 (jeton expiré, compte désactivé), le client l'oublie
 * (`adminToken.expire`), la coquille bascule et renvoie vers la connexion,
 * quelle que soit la page ouverte.
 */
export function AdminShell({
  title,
  description,
  actions,
  children,
}: {
  title: string;
  description?: ReactNode;
  actions?: ReactNode;
  children: ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const queryClient = useQueryClient();
  // Jeton lu hors rendu serveur. Instantané serveur : null → la coquille
  // (cadre, titre, description) est rendue, et pré-rendue au build, sans la
  // navigation ni le contenu : ils attendent le jeton, et l'effet ci-dessous
  // renvoie vers /login qui n'en a pas.
  const token = useSyncExternalStore(adminToken.subscribe, adminToken.get, () => null);
  const permissions = useAdminPermissions();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const menuButton = useRef<HTMLButtonElement>(null);
  const closeButton = useRef<HTMLButtonElement>(null);
  const opened = useRef(false);

  useEffect(() => {
    // Le STOCKAGE décide, pas la valeur rendue. Au chargement d'une page
    // (rechargement, lien ouvert dans un nouvel onglet), l'hydratation rend
    // l'instantané serveur, `null`, et cet effet s'exécute avant le rendu
    // qui lit le vrai jeton : il renvoyait vers /login un administrateur
    // bel et bien connecté, à chaque rechargement.
    if (token === null && adminToken.get() === null) {
      // Les données de la session partent avec elle : la coquille, rendue
      // sans jeton, relirait sinon un instant les totaux en cache, et un
      // autre administrateur dans cet onglet ceux du précédent.
      queryClient.removeQueries({ queryKey: ['admin'] });
      router.replace('/login');
    }
  }, [token, router, queryClient]);

  // Le focus suit le tiroir : il y entre à l'ouverture (le contenu dessous
  // est `inert`), et revient au bouton du menu à la fermeture.
  useEffect(() => {
    if (drawerOpen) {
      opened.current = true;
      closeButton.current?.focus();
    } else if (opened.current) {
      menuButton.current?.focus();
    }
  }, [drawerOpen]);

  // Le tiroir se referme avec Échap, comme toute surface posée par-dessus.
  useEffect(() => {
    if (!drawerOpen) return;
    const close = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setDrawerOpen(false);
    };
    window.addEventListener('keydown', close);
    return () => window.removeEventListener('keydown', close);
  }, [drawerOpen]);

  const brand = (
    <>
      <CarlysMark />
      <span className="leading-tight">
        <span className="block text-sm font-semibold">Carlys</span>{' '}
        <span className="block text-xs text-muted">Admin</span>
      </span>
    </>
  );

  return (
    <div className="flex min-h-full flex-1">
      {drawerOpen && (
        <div
          aria-hidden
          onClick={() => setDrawerOpen(false)}
          className="animate-fade fixed inset-0 z-30 bg-foreground/30 lg:hidden"
        />
      )}
      {/* Sur grand écran, ce cadre porte le fond et le filet sur TOUTE la
          hauteur de la page ; la barre, elle, reste fixée à l’écran. */}
      <div className="lg:w-60 lg:shrink-0 lg:border-r lg:border-border lg:bg-surface">
        <aside
          id="admin-sidebar"
          className={`fixed inset-y-0 left-0 z-40 flex w-64 flex-col border-r border-border bg-surface px-3 py-4 transition-[transform,visibility] duration-250 ease-out lg:w-60 lg:translate-x-0 lg:border-r-0 ${
            drawerOpen ? 'translate-x-0' : '-translate-x-full max-lg:invisible'
          }`}
        >
          <div className="flex items-center justify-between px-2">
            {/* Le logo suit la même règle que la redirection après connexion :
              la première page que les permissions ouvrent vraiment. */}
            {token === null ? (
              <span className="flex items-center gap-2.5">{brand}</span>
            ) : (
              <Link
                href={firstAllowedRoute(permissions)}
                className="flex items-center gap-2.5 rounded-lg focus-visible:outline-2 focus-visible:outline-primary"
              >
                {brand}
              </Link>
            )}
            <button
              ref={closeButton}
              type="button"
              onClick={() => setDrawerOpen(false)}
              aria-label="Fermer le menu"
              className="rounded-lg p-1.5 text-muted hover:bg-foreground/5 lg:hidden"
            >
              <CloseIcon />
            </button>
          </div>

          <div className="mt-8 flex-1 overflow-y-auto">
            <p className="px-3 pb-2 text-xs font-medium text-muted">Gestion</p>
            {/* Sans jeton, les permissions ne sont pas connues : un squelette
                neutre, pas une navigation qu'il faudrait corriger ensuite. */}
            {token === null ? (
              <div aria-hidden className="flex flex-col gap-0.5">
                {[0, 1, 2, 3, 4].map((index) => (
                  <div key={index} className="animate-skeleton h-9 rounded-lg bg-foreground/6" />
                ))}
              </div>
            ) : (
              <AdminNav permissions={permissions} pathname={pathname} />
            )}
          </div>

          <button
            type="button"
            onClick={() => {
              // Révocation côté serveur au mieux ; la session locale part tout de suite.
              void adminApi.logout();
              router.replace('/login');
            }}
            className="flex h-9 items-center gap-3 rounded-lg px-3 text-sm font-medium text-muted transition-colors duration-150 hover:bg-danger/8 hover:text-danger-ink"
          >
            <LogoutIcon />
            Se déconnecter
          </button>
        </aside>
      </div>

      <div className="flex min-w-0 flex-1 flex-col" inert={drawerOpen}>
        <header className="sticky top-0 z-20 flex h-14 items-center gap-3 border-b border-border bg-surface/90 px-4 backdrop-blur lg:hidden">
          <button
            ref={menuButton}
            type="button"
            onClick={() => setDrawerOpen(true)}
            aria-label="Ouvrir le menu"
            aria-expanded={drawerOpen}
            aria-controls="admin-sidebar"
            className="rounded-lg p-1.5 text-foreground hover:bg-foreground/5"
          >
            <MenuIcon />
          </button>
          <CarlysMark className="h-6" />
          <span className="text-sm font-semibold">{title}</span>
        </header>

        <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6 sm:px-6 lg:px-10 lg:py-10">
          <div className="animate-enter flex flex-wrap items-end justify-between gap-4">
            <div>
              <h1 className="text-2xl font-semibold tracking-tight sm:text-[1.75rem]">{title}</h1>
              {description !== undefined && (
                <p className="mt-1.5 max-w-2xl text-sm text-muted">{description}</p>
              )}
            </div>
            {actions}
          </div>
          {token !== null && <div className="mt-8">{children}</div>}
        </main>
      </div>
    </div>
  );
}
