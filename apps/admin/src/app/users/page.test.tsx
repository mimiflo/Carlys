import type { ManagedUserSummary } from '@carlys/api-contracts';
import { ADMIN_PERMISSIONS } from '@carlys/api-contracts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { adminApi, adminPermissions, adminToken, type Page } from '@/lib/admin-api';
import UsersPage from './page';

/**
 * La liste ne demandait QUE la première page. La route en sert vingt et porte
 * un curseur depuis toujours : le vingt-et-unième compte était inatteignable,
 * sans le moindre signe que la liste était coupée — alors que la carte
 * « Comptes », juste au-dessus, annonçait le vrai total.
 */

function compte(index: number): ManagedUserSummary {
  return {
    id: `${index}`.padStart(8, '0') + '-2222-4333-8444-555555555555',
    email: `membre${index}@carlys.test`,
    displayName: `Membre ${index}`,
    status: 'ACTIVE',
    emailVerified: true,
    isPremium: false,
    createdAt: '2026-09-01T10:00:00.000Z',
  };
}

function pageOf(items: ManagedUserSummary[], nextCursor: string | null): Page<ManagedUserSummary> {
  return { items, nextCursor, hasMore: nextCursor !== null };
}

vi.mock('next/navigation', () => ({
  usePathname: () => '/users',
  useRouter: () => ({ replace: vi.fn(), push: vi.fn() }),
}));

function renderPage() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <UsersPage />
    </QueryClientProvider>,
  );
}

afterEach(() => {
  vi.restoreAllMocks();
  adminToken.clear();
});

describe('Page Utilisateurs', () => {
  it('« Charger la suite » va chercher la page suivante et l’ajoute à la liste', async () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(ADMIN_PERMISSIONS);
    vi.spyOn(adminApi, 'overview').mockRejectedValue(new Error('hors sujet ici'));
    const listUsers = vi
      .spyOn(adminApi, 'listUsers')
      .mockResolvedValueOnce(pageOf([compte(1), compte(2)], 'curseur-page-2'))
      .mockResolvedValueOnce(pageOf([compte(3)], null));

    renderPage();
    await screen.findByText('membre1@carlys.test');

    fireEvent.click(screen.getByRole('button', { name: 'Charger la suite' }));

    expect(await screen.findByText('membre3@carlys.test')).toBeInTheDocument();
    // Les comptes déjà lus restent à l'écran : on empile, on ne remplace pas.
    expect(screen.getByText('membre1@carlys.test')).toBeInTheDocument();
    expect(listUsers).toHaveBeenLastCalledWith(undefined, 'curseur-page-2');
  });

  it('sans suite, aucun bouton ne le laisse croire', async () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(ADMIN_PERMISSIONS);
    vi.spyOn(adminApi, 'overview').mockRejectedValue(new Error('hors sujet ici'));
    vi.spyOn(adminApi, 'listUsers').mockResolvedValue(pageOf([compte(1)], null));

    renderPage();

    await screen.findByText('membre1@carlys.test');
    expect(screen.queryByRole('button', { name: 'Charger la suite' })).not.toBeInTheDocument();
  });

  it('une recherche repart de la PREMIÈRE page, sans curseur', async () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(ADMIN_PERMISSIONS);
    vi.spyOn(adminApi, 'overview').mockRejectedValue(new Error('hors sujet ici'));
    const listUsers = vi.spyOn(adminApi, 'listUsers').mockResolvedValue(pageOf([compte(1)], null));

    renderPage();
    await screen.findByText('membre1@carlys.test');

    fireEvent.change(screen.getByLabelText('Rechercher un utilisateur'), {
      target: { value: '  alice  ' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Rechercher' }));

    expect(await screen.findByText('membre1@carlys.test')).toBeInTheDocument();
    expect(listUsers).toHaveBeenLastCalledWith('alice', undefined);
  });
});
