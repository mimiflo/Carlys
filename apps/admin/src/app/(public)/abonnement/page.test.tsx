import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import SubscriptionCancelledPage from './page';
import SubscriptionThanksPage from './merci/page';

describe('Retours de paiement', () => {
  it('/abonnement/merci confirme l’abonnement et renvoie vers l’application', () => {
    render(<SubscriptionThanksPage />);

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Merci');
    expect(screen.getByText(/ton abonnement est actif/i)).toBeInTheDocument();
    expect(screen.getByText(/l’écran se met à jour tout seul/i)).toBeInTheDocument();
  });

  it('/abonnement rassure : rien n’a été débité', () => {
    render(<SubscriptionCancelledPage />);

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Paiement annulé');
    expect(screen.getByText(/rien n’a été débité/i)).toBeInTheDocument();
  });
});
