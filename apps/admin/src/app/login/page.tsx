'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import type { AdminLoginChallenge, AdminLoginResult } from '@carlys/api-contracts';
import { useState, useSyncExternalStore, type FormEvent } from 'react';
import { firstAllowedRoute } from '@/components/admin-shell';
import { LoginSecondFactor } from '@/components/login-second-factor';
import { ApiError, adminApi, adminPermissions, adminToken } from '@/lib/admin-api';
import { isNetworkFailure } from '@/lib/api-transport';
import { button, field } from '@/components/ui/button';
import { ArrowLeftIcon, CarlysMark } from '@/components/ui/icons';

/** Où en est la connexion : le mot de passe, puis le code de l'appli. */
function LoginSteps({ step }: { step: 1 | 2 }) {
  return (
    <ol
      className="mt-3 flex items-center gap-2 text-xs text-muted"
      aria-label="Étapes de connexion"
    >
      {(['Mot de passe', 'Code de vérification'] as const).map((label, index) => {
        const current = index + 1 === step;
        return (
          <li
            key={label}
            aria-current={current ? 'step' : undefined}
            className="flex items-center gap-2"
          >
            {index > 0 && <span aria-hidden className="h-px w-4 bg-border" />}
            <span
              aria-hidden
              className={`flex h-5 w-5 items-center justify-center rounded-full text-[0.6875rem] font-semibold transition-colors duration-250 ${
                index + 1 <= step ? 'bg-primary text-white' : 'bg-surface-alt text-muted'
              }`}
            >
              {index + 1}
            </span>
            <span className={current ? 'font-medium text-foreground' : undefined}>{label}</span>
          </li>
        );
      })}
    </ol>
  );
}

/**
 * La phrase d'une connexion refusée, décidée par sa CAUSE.
 *
 * Tout ce qui n'était pas un 401 affichait « vérifiez que l'API est
 * démarrée » : une consigne de développeur, servie en production, au
 * vouvoiement, et fausse pour un compte verrouillé après trop d'essais (429),
 * à qui elle faisait chercher une panne qui n'existait pas.
 */
function loginFailureMessage(cause: unknown): string {
  if (cause instanceof ApiError && cause.status === 401) {
    return 'E-mail ou mot de passe incorrect.';
  }
  // 403 : mot de passe juste, mais aucune double authentification émise —
  // le serveur dit quelle commande l'opérateur doit lancer.
  if (cause instanceof ApiError && cause.status === 403) return cause.message;
  if (cause instanceof ApiError && cause.status === 429) {
    return 'Trop de tentatives : patiente quelques minutes avant de réessayer.';
  }
  if (isNetworkFailure(cause)) {
    return 'Connexion impossible pour le moment : le serveur ne répond pas. Réessaie dans un instant.';
  }
  return 'Connexion impossible pour le moment. Réessaie dans un instant.';
}

/**
 * Connexion administrateur (comptes séparés des comptes mobiles), en DEUX
 * étapes : le mot de passe, puis le code de l'appli d'authentification
 * (double authentification) — la première fois, son QR code à scanner.
 * Le jeton vit en sessionStorage : fermer l'onglet clôt la session locale ;
 * chaque requête reste revérifiée côté serveur.
 */
export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setSubmitting] = useState(false);
  const [challenge, setChallenge] = useState<AdminLoginChallenge | null>(null);
  // Arrivé ici parce que le serveur a refusé le jeton (`adminToken.expire`) :
  // le dire, sinon la page de connexion surgit sans explication.
  const expired = useSyncExternalStore(adminToken.subscribe, adminToken.wasExpired, () => false);

  const onSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      // Le mot de passe juste n'ouvre pas la session : il ouvre l'étape du code.
      setChallenge(await adminApi.login(email, password));
      setPassword('');
    } catch (cause) {
      setError(loginFailureMessage(cause));
    }
    setSubmitting(false);
  };

  const onSignedIn = (result: AdminLoginResult) => {
    adminToken.set(result.accessToken);
    // La réponse de connexion porte DÉJÀ les permissions : elles étaient
    // jetées, et la navigation était en dur.
    adminPermissions.set(result.admin.permissions);
    router.replace(firstAllowedRoute(result.admin.permissions));
  };

  return (
    <main className="flex flex-1 flex-col items-center justify-center px-4 py-12">
      <div className="animate-enter w-full max-w-sm rounded-xl border border-border bg-surface p-8 shadow-sm">
        <CarlysMark className="h-10" />
        <h1 className="mt-6 text-xl font-semibold tracking-tight">Connexion administrateur</h1>
        <LoginSteps step={challenge === null ? 1 : 2} />
        {expired && (
          <p role="status" className="mt-2 text-sm text-muted">
            Ta session a expiré : reconnecte-toi pour continuer.
          </p>
        )}
        {challenge !== null ? (
          <LoginSecondFactor
            challenge={challenge}
            onSignedIn={onSignedIn}
            onRestart={() => setChallenge(null)}
          />
        ) : (
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
                className={`${field} text-base`}
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
                className={`${field} text-base`}
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
              className={`${button('primary')} mt-1 h-10`}
            >
              {isSubmitting ? 'Connexion…' : 'Se connecter'}
            </button>
          </form>
        )}
      </div>
      <Link
        href="/"
        className="mt-6 inline-flex items-center gap-1.5 text-sm font-medium text-muted transition-colors duration-150 hover:text-foreground"
      >
        <ArrowLeftIcon width={14} height={14} />
        Retour à l’accueil
      </Link>
    </main>
  );
}
