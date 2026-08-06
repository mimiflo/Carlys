import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { Providers } from './providers';
import Home from './page';

describe("Page d'accueil admin", () => {
  it('affiche le titre et le lien de connexion', () => {
    render(
      <Providers>
        <Home />
      </Providers>,
    );

    expect(
      screen.getByRole('heading', { name: /tableau de bord d’administration/i }),
    ).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /connexion administrateur/i })).toHaveAttribute(
      'href',
      '/login',
    );
  });
});
