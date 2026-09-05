import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import TermsPage from './page';

/** La page lit docs/legal/terms.md au build : le test lit le vrai fichier. */
describe('Page /terms', () => {
  it('rend les conditions d’utilisation du dépôt', async () => {
    const { container } = render(await TermsPage());

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(
      /conditions d.utilisation/i,
    );
    expect(container).toHaveTextContent(/âge minimum|au moins 15 ans/i);
    expect(container).toHaveTextContent(/n.est pas un dispositif médical/i);
  });

  it('respecte le ton du produit : tutoiement, sans tiret cadratin', async () => {
    const { container } = render(await TermsPage());

    expect(container.textContent).not.toContain('—');
    expect(container.textContent).toMatch(/\btu\b/i);
    expect(container.textContent).not.toMatch(/\b(vous|votre|vos)\b/i);
  });
});
