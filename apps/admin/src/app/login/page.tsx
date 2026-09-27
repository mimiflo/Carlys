'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState, useSyncExternalStore, type FormEvent } from 'react';
import { firstAllowedRoute } from '@/components/admin-shell';
import { AdminApiError, adminApi, adminPermissions, adminToken } from '@/lib/admin-api';
import { isNetworkFailure } from '@/lib/api-transport';

/**
 * La phrase d'une connexion refusée, décidée par sa CAUSE.
 *
 * Tout ce qui n'était pas un 401 affichait « vérifiez que l'API est
 * démarrée » : une consigne de développeur, servie en production, au
 * vouvoiement, et fausse pour un compte verrouillé après trop d'essais (429),
 * à qui elle faisait chercher une panne qui n'existait pas.
 */
function loginFailureMessage(cause: unknown): string {
  if (cause instanceof AdminApiError && cause.status === 401) {
    return 'E-mail ou mot de passe incorrect.';
  }
  if (cause instanceof AdminApiError && cause.status === 429) {
    return 'Trop de tentatives : patiente quelques minutes avant de réessayer.';
  }
  if (isNetworkFailure(cause)) {
    return 'Connexion impossible pour le moment : le serveur ne répond pas. Réessaie dans un instant.';
  }
  return 'Connexion impossible pour le moment. Réessaie dans un instant.';
}

/**
 * Connexion administrateur (comptes séparés des comptes mobiles).
 * Le jeton vit en sessionStorage : fermer l'onglet clôt la session locale ;
 * chaque requête reste revérifiée côté serveur.
 */
export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setSubmitting] = useState(false);
  // Arrivé ici parce que le serveur a refusé le jeton (`adminToken.expire`) :
  // le dire, sinon la page de connexion surgit sans explication.
  const expired = useSyncExternalStore(adminToken.subscribe, adminToken.wasExpired, () => false);

  const onSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const result = await adminApi.login(email, password);
      adminToken.set(result.accessToken);
      // La réponse de connexion porte DÉJÀ les permissions : elles étaient
      // jetées, et la navigation était en dur.
      adminPermissions.set(result.admin.permissions);
      router.replace(firstAllowedRoute(result.admin.permissions));
    } catch (cause) {
      setError(loginFailureMessage(cause));
      setSubmitting(false);
    }
  };

  return (
    <main className="flex flex-1 items-center justify-center p-8">
      <div className="w-full max-w-md rounded-2xl bg-surface p-8 shadow-sm ring-1 ring-black/5">
        <h1 className="text-2xl font-bold tracking-tight">Connexion administrateur</h1>
        {expired && (
          <p role="status" className="mt-2 text-sm text-muted">
            Ta session a expiré : reconnecte-toi pour continuer.
          </p>
        )}
        <form onSubmit={onSubmit} className="mt-6 flex flex-col gap-4" noValidate>
          <label className="flex flex-col gap-1 text-sm font-medium">
            Adresse e-mail
            <input
              type="email"
              name="email"
              autoComplete="username"
              required
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              className="rounded-lg border border-black/10 px-3 py-2 text-base focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary"
            />
          </label>
          <label className="flex flex-col gap-1 text-sm font-medium">
            Mot de passe
            <input
              type="password"
              name="password"
              autoComplete="current-password"
              required
              minLength={8}
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="rounded-lg border border-black/10 px-3 py-2 text-base focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary"
            />
          </label>
          {error !== null && (
            <p role="alert" className="text-sm font-medium text-danger-ink">
              {error}
            </p>
          )}
          <button
            type="submit"
            disabled={isSubmitting || email === '' || password.length < 8}
            className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-dark disabled:opacity-50"
          >
            {isSubmitting ? 'Connexion…' : 'Se connecter'}
          </button>
        </form>
        <Link href="/" className="mt-6 inline-block text-sm font-medium text-primary-ink underline">
          ← Retour à l’accueil
        </Link>
      </div>
    </main>
  );
}
