'use client';

import type { AdminLoginChallenge, AdminLoginResult } from '@carlys/api-contracts';
import { useState, type FormEvent } from 'react';
import { ApiError, adminApi } from '@/lib/admin-api';
import { isNetworkFailure } from '@/lib/api-transport';

function codeFailureMessage(cause: unknown): string {
  // 401 : code faux ou déjà servi, ou étape expirée ; 403 : 2FA gelée après
  // trop de codes faux — le serveur dit lequel, et quoi faire.
  if (cause instanceof ApiError && (cause.status === 401 || cause.status === 403)) {
    return cause.message;
  }
  if (cause instanceof ApiError && cause.status === 429) {
    return 'Trop de codes faux : patiente quelques minutes avant de réessayer.';
  }
  if (isNetworkFailure(cause)) {
    return 'Connexion impossible pour le moment : le serveur ne répond pas. Réessaie dans un instant.';
  }
  return 'Vérification impossible pour le moment. Réessaie dans un instant.';
}

/**
 * SECONDE étape de la connexion : le code à 6 chiffres de l'appli
 * d'authentification. Le QR code ne s'affiche jamais ici : il s'émet sur le
 * terminal du serveur (`carlysctl admin-create … --reset-2fa`).
 */
export function LoginSecondFactor({
  challenge,
  onSignedIn,
  onRestart,
}: {
  challenge: AdminLoginChallenge;
  onSignedIn: (result: AdminLoginResult) => void;
  onRestart: () => void;
}) {
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setSubmitting] = useState(false);

  const onSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      onSignedIn(await adminApi.verifyTotp(challenge.challengeToken, code));
    } catch (cause) {
      setError(codeFailureMessage(cause));
      setCode('');
      setSubmitting(false);
    }
  };

  return (
    <form onSubmit={onSubmit} className="mt-6 flex flex-col gap-4" noValidate>
      <p className="text-sm text-muted">
        Saisis le code à 6 chiffres affiché par ton appli d’authentification.
      </p>
      <label className="flex flex-col gap-1 text-sm font-medium">
        Code à 6 chiffres
        <input
          name="code"
          inputMode="numeric"
          autoComplete="one-time-code"
          pattern="[0-9]{6}"
          maxLength={6}
          required
          autoFocus
          value={code}
          onChange={(event) => setCode(event.target.value.replace(/\D/g, ''))}
          className="rounded-lg border border-black/10 px-3 py-2 text-center font-mono text-lg tracking-[0.4em] focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary"
        />
      </label>
      {error !== null && (
        <p role="alert" className="text-sm font-medium text-danger-ink">
          {error}
        </p>
      )}
      <button
        type="submit"
        disabled={isSubmitting || code.length !== 6}
        className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-dark disabled:opacity-50"
      >
        {isSubmitting ? 'Vérification…' : 'Valider'}
      </button>
      <button
        type="button"
        onClick={onRestart}
        className="text-sm font-medium text-primary-ink underline"
      >
        Recommencer avec mon mot de passe
      </button>
    </form>
  );
}
