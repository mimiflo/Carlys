import type { Metadata } from 'next';
import { Suspense } from 'react';
import { PublicPage } from '@/components/public-page';
import { ResetPasswordForm } from './reset-password-form';

export const metadata: Metadata = {
  title: 'Nouveau mot de passe · Carlys',
};

/**
 * Cible du lien « mot de passe oublié » envoyé par l'API
 * (`${PUBLIC_APP_URL}/reset-password?token=…`). Le formulaire lit l'URL,
 * donc il est rendu côté client sous une frontière Suspense.
 */
export default function ResetPasswordPage() {
  return (
    <PublicPage title="Nouveau mot de passe">
      <Suspense fallback={<p className="text-muted">Chargement…</p>}>
        <ResetPasswordForm />
      </Suspense>
    </PublicPage>
  );
}
