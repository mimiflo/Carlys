import Link from 'next/link';
import { ApiStatus } from '@/components/api-status';

export default function Home() {
  return (
    <main className="flex flex-1 items-center justify-center p-8">
      <div className="w-full max-w-xl rounded-2xl bg-surface p-8 shadow-sm ring-1 ring-black/5">
        <p className="text-sm font-medium uppercase tracking-widest text-primary">Carlys</p>
        <h1 className="mt-2 text-3xl font-bold tracking-tight">Tableau de bord d’administration</h1>
        <p className="mt-4 text-muted">
          Fondation du projet (Étape 1). L’authentification administrateur, la gestion des
          utilisateurs, des exercices et des abonnements arrivent avec les prochaines tranches
          verticales.
        </p>

        <section className="mt-8" aria-labelledby="api-status-title">
          <h2 id="api-status-title" className="text-sm font-semibold uppercase tracking-wide">
            État de la plateforme
          </h2>
          <div className="mt-3">
            <ApiStatus />
          </div>
        </section>

        <div className="mt-8 flex gap-4">
          <Link
            href="/login"
            className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-dark focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
          >
            Connexion administrateur
          </Link>
        </div>
      </div>
    </main>
  );
}
