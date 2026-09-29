import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import PrivacyPage from './page';

/** La page lit docs/legal/privacy.md au build : le test lit le vrai fichier. */
describe('Page /privacy', () => {
  it('rend la politique de confidentialité du dépôt', async () => {
    const { container } = render(await PrivacyPage());

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(
      /politique de confidentialité/i,
    );
    // Le coach tourne sur le serveur de Carlys (COACH_API_BASE_URL vise
    // l'Ollama interne, ADR 0011) : la page doit le dire, et ne plus nommer
    // un prestataire qui ne reçoit rien. Le paiement a le sien.
    expect(container).toHaveTextContent('sur son propre serveur');
    expect(container).not.toHaveTextContent('Mistral');
    expect(container).toHaveTextContent('Stripe');
    expect(container).toHaveTextContent('Firebase Cloud Messaging');
  });

  it('respecte le ton du produit : tutoiement, sans tiret cadratin', async () => {
    const { container } = render(await PrivacyPage());

    expect(container.textContent).not.toContain('—');
    expect(container.textContent).toMatch(/\btes données\b/i);
    expect(container.textContent).not.toMatch(/\b(vous|votre|vos)\b/i);
  });
});
