'use client';

import { PASSWORD_MAX_LENGTH, PASSWORD_MIN_LENGTH } from '@carlys/api-contracts';
import { useMutation } from '@tanstack/react-query';
import { useSearchParams } from 'next/navigation';
import { useState, type FormEvent } from 'react';
import { z } from 'zod';
import { PublicNotice } from '@/components/public-page';
import { publicApi, publicFailureMessage } from '@/lib/public-api';

const INPUT_CLASSES =
  'rounded-lg border border-black/10 px-3 py-2 text-base focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary';

/** Mêmes bornes que le DTO de l'API : refuser ici ce que le serveur refuserait. */
const formSchema = z
  .object({
    newPassword: z
      .string()
      .min(
        PASSWORD_MIN_LENGTH,
        `Le mot de passe doit contenir au moins ${PASSWORD_MIN_LENGTH} caractères.`,
      )
      .max(
        PASSWORD_MAX_LENGTH,
        `Le mot de passe ne peut pas dépasser ${PASSWORD_MAX_LENGTH} caractères.`,
      ),
    confirmation: z.string(),
  })
  .refine((values) => values.newPassword === values.confirmation, {
    message: 'Les deux mots de passe ne sont pas identiques.',
    path: ['confirmation'],
  });

const FAILURE_BY_STATUS = {
  401: 'Ce lien est expiré ou n’est plus valable. Refais une demande de réinitialisation depuis l’application.',
  400: `Le mot de passe envoyé ne respecte pas les règles (${PASSWORD_MIN_LENGTH} à ${PASSWORD_MAX_LENGTH} caractères).`,
} as const;

/**
 * Formulaire ouvert depuis le lien reçu par e-mail : le jeton vient de
 * l'URL, le mot de passe de la personne, et l'appel part vers
 * `POST /auth/reset-password`, qui révoque toutes les sessions.
 */
export function ResetPasswordForm() {
  const token = useSearchParams().get('token');
  const [newPassword, setNewPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [formError, setFormError] = useState<string | null>(null);

  const reset = useMutation({
    mutationFn: (input: { token: string; newPassword: string }) =>
      publicApi.resetPassword(input.token, input.newPassword),
  });

  if (token === null || token === '') {
    return (
      <PublicNotice tone="error">
        Ce lien est incomplet. Ouvre l’e-mail que tu as reçu et clique de nouveau sur son lien, ou
        refais une demande depuis l’application.
      </PublicNotice>
    );
  }

  if (reset.isSuccess) {
    return (
      <PublicNotice tone="success">
        Ton mot de passe est changé, tu peux te connecter dans l’application.
      </PublicNotice>
    );
  }

  const onSubmit = (event: FormEvent) => {
    event.preventDefault();
    const parsed = formSchema.safeParse({ newPassword, confirmation });
    if (!parsed.success) {
      setFormError(parsed.error.issues[0]?.message ?? 'Mot de passe invalide.');
      return;
    }
    setFormError(null);
    reset.mutate({ token, newPassword: parsed.data.newPassword });
  };

  const error =
    formError ?? (reset.isError ? publicFailureMessage(reset.error, FAILURE_BY_STATUS) : null);

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-4" noValidate>
      <p className="text-muted">
        Choisis un nouveau mot de passe. Tous tes appareils seront déconnectés : tu te reconnecteras
        avec celui-ci.
      </p>
      <label className="flex flex-col gap-1 text-sm font-medium">
        Nouveau mot de passe
        <input
          type="password"
          name="newPassword"
          autoComplete="new-password"
          required
          minLength={PASSWORD_MIN_LENGTH}
          maxLength={PASSWORD_MAX_LENGTH}
          value={newPassword}
          onChange={(event) => setNewPassword(event.target.value)}
          className={INPUT_CLASSES}
        />
        <span className="text-xs font-normal text-muted">
          {PASSWORD_MIN_LENGTH} caractères minimum.
        </span>
      </label>
      <label className="flex flex-col gap-1 text-sm font-medium">
        Confirme le mot de passe
        <input
          type="password"
          name="confirmation"
          autoComplete="new-password"
          required
          value={confirmation}
          onChange={(event) => setConfirmation(event.target.value)}
          className={INPUT_CLASSES}
        />
      </label>
      {error !== null && <PublicNotice tone="error">{error}</PublicNotice>}
      <button
        type="submit"
        disabled={reset.isPending}
        className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-primary-dark disabled:opacity-50"
      >
        {reset.isPending ? 'Enregistrement…' : 'Changer mon mot de passe'}
      </button>
    </form>
  );
}
