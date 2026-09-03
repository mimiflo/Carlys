import Link from 'next/link';
import type { ReactNode } from 'react';

/**
 * Mise en page des pages PUBLIQUES du produit : liens reçus par e-mail,
 * retours de paiement, textes légaux. Rien de la coquille d'administration
 * n'apparaît ici, et surtout aucun lien vers /login : une personne qui
 * arrive depuis un e-mail n'a rien à faire dans le back-office.
 */
export default function PublicLayout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-full flex-1 flex-col">
      <header className="border-b border-black/5 bg-surface">
        <div className="mx-auto w-full max-w-2xl px-6 py-4">
          <span className="text-sm font-bold uppercase tracking-widest text-primary">Carlys</span>
        </div>
      </header>
      <main className="mx-auto w-full max-w-2xl flex-1 px-6 py-10">{children}</main>
      <footer className="border-t border-black/5">
        <nav
          aria-label="Informations légales"
          className="mx-auto flex w-full max-w-2xl flex-wrap gap-4 px-6 py-4 text-sm text-muted"
        >
          <Link href="/privacy" className="transition-colors hover:text-primary">
            Politique de confidentialité
          </Link>
          <Link href="/terms" className="transition-colors hover:text-primary">
            Conditions d’utilisation
          </Link>
        </nav>
      </footer>
    </div>
  );
}
