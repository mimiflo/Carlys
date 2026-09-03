import type { Metadata } from 'next';
import { Suspense } from 'react';
import { PublicPage } from '@/components/public-page';
import { VerifyEmailStatus } from './verify-email-status';

export const metadata: Metadata = {
  title: 'Vérification de ton adresse · Carlys',
};

/**
 * Cible du lien de vérification envoyé à l'inscription
 * (`${PUBLIC_APP_URL}/verify-email?token=…`). Le composant lit l'URL et
 * appelle l'API dès l'ouverture, sous une frontière Suspense.
 */
export default function VerifyEmailPage() {
  return (
    <PublicPage title="Vérification de ton adresse e-mail">
      <Suspense fallback={<p className="text-muted">Chargement…</p>}>
        <VerifyEmailStatus />
      </Suspense>
    </PublicPage>
  );
}
