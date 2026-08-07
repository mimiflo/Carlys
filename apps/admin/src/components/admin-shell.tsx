'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useSyncExternalStore, type ReactNode } from 'react';
import { adminToken } from '@/lib/admin-api';

const NAV_ITEMS = [
  { href: '/users', label: 'Utilisateurs' },
  { href: '/audit', label: 'Journal d’audit' },
] as const;

/**
 * Coquille des pages du back-office : barre de navigation, déconnexion et
 * garde de session côté client (redirection immédiate vers /login sans
 * jeton — le VRAI contrôle d'accès reste côté serveur, sur chaque requête).
 */
const subscribeNoop = () => () => {};

export function AdminShell({ title, children }: { title: string; children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  // Jeton lu hors rendu serveur (instantané serveur : null → rien n'est
  // affiché avant l'hydratation, puis redirection si non connecté).
  const token = useSyncExternalStore(subscribeNoop, adminToken.get, () => null);

  useEffect(() => {
    if (token === null) {
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
          <Link href="/users" className="text-sm font-bold uppercase tracking-widest text-primary">
            Carlys Admin
          </Link>
          <nav aria-label="Navigation d’administration" className="flex gap-4">
            {NAV_ITEMS.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                aria-current={pathname.startsWith(item.href) ? 'page' : undefined}
                className={`text-sm font-medium transition-colors hover:text-primary ${
                  pathname.startsWith(item.href) ? 'text-primary' : 'text-muted'
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
            className="ml-auto text-sm font-medium text-muted transition-colors hover:text-danger"
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
