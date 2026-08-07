'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';
import { AdminApiError, adminApi, adminToken } from '@/lib/admin-api';

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

  const onSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const result = await adminApi.login(email, password);
      adminToken.set(result.accessToken);
      router.replace('/users');
    } catch (cause) {
      setError(
        cause instanceof AdminApiError && cause.status === 401
          ? 'E-mail ou mot de passe incorrect.'
          : 'Connexion impossible — vérifiez que l’API est démarrée.',
      );
      setSubmitting(false);
    }
  };

  return (
    <main className="flex flex-1 items-center justify-center p-8">
      <div className="w-full max-w-md rounded-2xl bg-surface p-8 shadow-sm ring-1 ring-black/5">
        <h1 className="text-2xl font-bold tracking-tight">Connexion administrateur</h1>
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
            <p role="alert" className="text-sm font-medium text-danger">
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
        <Link href="/" className="mt-6 inline-block text-sm font-medium text-primary underline">
          ← Retour à l’accueil
        </Link>
      </div>
    </main>
  );
}
