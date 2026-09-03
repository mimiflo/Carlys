import type { Metadata } from 'next';
import { PublicPage } from '@/components/public-page';

export const metadata: Metadata = {
  title: 'Paiement annulé · Carlys',
};

/** Retour de Stripe quand la page de paiement est quittée (`cancel_url`). */
export default function SubscriptionCancelledPage() {
  return (
    <PublicPage title="Paiement annulé">
      <p>Paiement annulé, rien n’a été débité.</p>
      <p className="text-sm text-muted">
        Tu peux retourner dans l’application et relancer l’abonnement quand tu veux.
      </p>
    </PublicPage>
  );
}
