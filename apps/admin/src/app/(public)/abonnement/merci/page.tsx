import type { Metadata } from 'next';
import { PublicPage } from '@/components/public-page';

export const metadata: Metadata = {
  title: 'Abonnement actif · Carlys',
};

/**
 * Retour de Stripe après un paiement réussi (`success_url`). Le droit, lui,
 * n'est jamais décidé ici : c'est le webhook signé qui l'accorde, et
 * l'application le relit au retour au premier plan.
 */
export default function SubscriptionThanksPage() {
  return (
    <PublicPage title="Merci !">
      <p>Merci, ton abonnement est actif.</p>
      <p>Retourne dans l’application : l’écran se met à jour tout seul.</p>
      <p className="text-sm text-muted">
        Si l’application affiche encore le plan gratuit après quelques secondes, ferme-la puis
        rouvre-la : l’écran se rafraîchit à chaque retour au premier plan.
      </p>
    </PublicPage>
  );
}
