import type { ManagedUserSummary } from '@carlys/api-contracts';
import { ADMIN_PERMISSIONS } from '@carlys/api-contracts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
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

const router = vi.hoisted(() => ({ replace: vi.fn(), push: vi.fn() }));

vi.mock('next/navigation', () => ({
  usePathname: () => '/users',
  useRouter: () => router,
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
  vi.unstubAllGlobals();
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

  /**
   * Une URL finit dans le journal d'accès Nginx, dans celui de l'API et dans
   * l'historique du navigateur. La recherche d'un membre porte souvent son
   * adresse e-mail : elle ne doit apparaître dans AUCUNE, ni celle de la
   * requête (première page comme suite), ni la barre d'adresse, ni une
   * entrée d'historique.
   */
  it('l’adresse cherchée ne paraît dans aucune URL, pagination comprise', async () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(ADMIN_PERMISSIONS);
    vi.spyOn(adminApi, 'overview').mockRejectedValue(new Error('hors sujet ici'));
    const adresse = 'alice.martin+carlys@exemple.fr';
    // Le client n'envoie que des corps JSON, donc des chaînes.
    const corps = (init?: RequestInit): string => (typeof init?.body === 'string' ? init.body : '');
    const fetchMock = vi.fn((_url: string, init?: RequestInit) => {
      const suite = corps(init).includes('curseur-page-2');
      return Promise.resolve(
        new Response(
          JSON.stringify({
            data: [compte(suite ? 3 : 1)],
            meta: { nextCursor: suite ? null : 'curseur-page-2', hasMore: !suite },
            requestId: 'req-1',
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
      );
    });
    vi.stubGlobal('fetch', fetchMock);
    const pushState = vi.spyOn(window.history, 'pushState');
    const replaceState = vi.spyOn(window.history, 'replaceState');

    renderPage();
    await screen.findByText('membre1@carlys.test');
    fireEvent.change(screen.getByLabelText('Rechercher un utilisateur'), {
      target: { value: adresse },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Rechercher' }));
    await waitFor(() => {
      expect(fetchMock.mock.calls.some(([, init]) => corps(init).includes(adresse))).toBe(true);
    });
    fireEvent.click(await screen.findByRole('button', { name: 'Charger la suite' }));
    expect(await screen.findByText('membre3@carlys.test')).toBeInTheDocument();

    // La recherche est bien partie, première page ET suite : dans un corps de POST.
    const recherches = fetchMock.mock.calls.filter(([, init]) => corps(init).includes(adresse));
    expect(recherches).toHaveLength(2);
    expect(recherches.every(([, init]) => init?.method === 'POST')).toBe(true);

    const urls = [
      ...fetchMock.mock.calls.map(([url]) => url),
      window.location.href,
      ...[...pushState.mock.calls, ...replaceState.mock.calls].map((call) => String(call[2])),
      ...[...router.push.mock.calls, ...router.replace.mock.calls].map((call) => String(call[0])),
    ];
    for (const url of urls) {
      expect(decodeURIComponent(url)).not.toContain('alice');
    }
  });
});
