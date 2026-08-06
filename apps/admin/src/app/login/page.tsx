import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Connexion — Carlys Admin',
};

/**
 * Emplacement de l'authentification administrateur.
 * Volontairement non fonctionnel à l'Étape 1 : le système de comptes admin
 * (rôles, permissions, audit) est livré à l'Étape 7 — aucun faux formulaire
 * qui prétendrait fonctionner.
 */
export default function LoginPage() {
  return (
    <main className="flex flex-1 items-center justify-center p-8">
      <div className="w-full max-w-md rounded-2xl bg-surface p-8 shadow-sm ring-1 ring-black/5">
        <h1 className="text-2xl font-bold tracking-tight">Connexion administrateur</h1>
        <p className="mt-4 text-sm text-muted">
          L’authentification sécurisée des administrateurs (rôles, permissions, journal d’audit)
          sera livrée à l’Étape 7, après les tranches verticales métier. Elle n’est pas simulée ici.
        </p>
        <Link href="/" className="mt-6 inline-block text-sm font-medium text-primary underline">
          ← Retour à l’accueil
        </Link>
      </div>
    </main>
  );
}
