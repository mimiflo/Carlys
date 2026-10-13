import Link from 'next/link';
import { ApiStatus } from '@/components/api-status';
import { button } from '@/components/ui/button';
import { ArrowRightIcon, CarlysMark, ShieldIcon } from '@/components/ui/icons';

/**
 * L'accueil PUBLIC : l'état de la plateforme, lisible sans connexion, et la
 * porte du back-office. Rien d'autre n'y est montré.
 */
export default function Home() {
  return (
    <div className="flex flex-1 flex-col">
      <header className="mx-auto flex w-full max-w-3xl items-center justify-between px-6 py-6">
        <span className="flex items-center gap-2.5 text-sm font-semibold">
          <CarlysMark />
          Carlys
        </span>
        <Link href="/login" className={button('secondary', 'sm')}>
          Se connecter
        </Link>
      </header>

      <main className="mx-auto w-full max-w-3xl flex-1 px-6 pb-16 pt-8 sm:pt-16">
        <div className="animate-enter">
          <p className="inline-flex items-center gap-2 rounded-full bg-primary/10 px-3 py-1 text-xs font-medium text-primary-ink">
            <ShieldIcon width={14} height={14} />
            Espace réservé à l’équipe Carlys
          </p>
          <h1 className="mt-5 text-3xl font-semibold tracking-tight sm:text-4xl">
            Tableau de bord d’administration
          </h1>
          <p className="mt-4 max-w-xl text-base text-muted">
            Gestion des utilisateurs, des droits premium et du catalogue, et journal d’audit.
            Connecte-toi avec un compte administrateur : les comptes admin sont séparés des comptes
            de l’application mobile.
          </p>
          <Link href="/login" className={`${button('primary')} mt-8`}>
            Connexion administrateur
            <ArrowRightIcon width={16} height={16} />
          </Link>
        </div>

        <section
          aria-labelledby="api-status-title"
          className="animate-enter mt-14 rounded-xl border border-border bg-surface p-6"
        >
          <div className="flex items-baseline justify-between gap-4">
            <h2 id="api-status-title" className="text-base font-semibold">
              État de la plateforme
            </h2>
            <span className="text-xs text-muted">Actualisé toutes les 15 s</span>
          </div>
          <div className="mt-4">
            <ApiStatus />
          </div>
        </section>
      </main>

      <footer className="mx-auto flex w-full max-w-3xl gap-6 px-6 py-8 text-xs text-muted">
        <Link href="/privacy" className="hover:text-foreground">
          Confidentialité
        </Link>
        <Link href="/terms" className="hover:text-foreground">
          Conditions d’utilisation
        </Link>
      </footer>
    </div>
  );
}
