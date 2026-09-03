import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import PublicLayout from './layout';

describe('Mise en page publique', () => {
  it('rend le contenu, les liens légaux, et aucun accès au back-office', () => {
    render(
      <PublicLayout>
        <p>Contenu public</p>
      </PublicLayout>,
    );

    expect(screen.getByText('Contenu public')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /politique de confidentialité/i })).toHaveAttribute(
      'href',
      '/privacy',
    );
    expect(screen.getByRole('link', { name: /conditions d’utilisation/i })).toHaveAttribute(
      'href',
      '/terms',
    );
    for (const link of screen.getAllByRole('link')) {
      expect(link).not.toHaveAttribute('href', '/login');
    }
    expect(screen.queryByRole('button', { name: /se déconnecter/i })).toBeNull();
  });
});
