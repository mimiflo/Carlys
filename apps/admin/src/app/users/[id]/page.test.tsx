import type { ManagedUserDetail } from '@carlys/api-contracts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AdminApiError, adminApi, adminToken } from '@/lib/admin-api';
import UserDetailPage from './page';

const USER: ManagedUserDetail = {
  id: '11111111-2222-4333-8444-555555555555',
  email: 'membre@carlys.test',
  displayName: 'Membre',
  status: 'ACTIVE',
  emailVerified: true,
  isPremium: false,
  createdAt: '2026-08-07T10:00:00.000Z',
  sessionsCount: 2,
  completedWorkoutsCount: 14,
  entitlements: [{ key: 'premium_exercises', isActive: false, expiresAt: null }],
};

const routerReplace = vi.fn();

// La page lit l'identifiant dans l'URL et la coquille garde la session :
// hors de Next, ces hooks n'ont pas de routeur, on leur en donne un.
vi.mock('next/navigation', () => ({
  useParams: () => ({ id: USER.id }),
  usePathname: () => `/users/${USER.id}`,
  useRouter: () => ({ replace: routerReplace, push: vi.fn() }),
}));

/** Sans nouvelle tentative : un échec doit se voir tout de suite, pas après un délai. */
function renderPage() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>
      <UserDetailPage />
    </QueryClientProvider>,
  );
}

afterEach(() => {
  vi.restoreAllMocks();
  // restoreAllMocks ne touche pas aux vi.fn() : sans remise à zéro, un appel
  // d'un cas précédent satisferait l'assertion du cas « sans jeton ».
  routerReplace.mockClear();
  adminToken.clear();
});

describe('Fiche utilisateur', () => {
  it('accorde le premium en envoyant l’INVERSE du plan actuel', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'userDetail').mockResolvedValue(USER);
    const setEntitlement = vi
      .spyOn(adminApi, 'setEntitlement')
      .mockResolvedValue({ ...USER, isPremium: true });

    renderPage();

    fireEvent.click(await screen.findByRole('button', { name: /accorder le premium/i }));

    await waitFor(() => {
      expect(setEntitlement).toHaveBeenCalledWith(USER.id, 'premium_exercises', true);
    });
  });

  it('retire le premium d’un compte qui l’a déjà', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'userDetail').mockResolvedValue({ ...USER, isPremium: true });
    const setEntitlement = vi
      .spyOn(adminApi, 'setEntitlement')
      .mockResolvedValue({ ...USER, isPremium: false });

    renderPage();

    fireEvent.click(await screen.findByRole('button', { name: /retirer le premium/i }));

    await waitFor(() => {
      expect(setEntitlement).toHaveBeenCalledWith(USER.id, 'premium_exercises', false);
    });
  });

  it('montre un refus de permission (403) comme tel, pas comme une panne', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'userDetail').mockResolvedValue(USER);
    vi.spyOn(adminApi, 'setEntitlement').mockRejectedValue(
      new AdminApiError('Permission entitlement:grant requise.', 403),
    );

    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: /accorder le premium/i }));

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('Permission manquante pour cette action.');
    expect(alert).not.toHaveTextContent('Action impossible');
  });

  it('montre une panne serveur comme une action à réessayer', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'userDetail').mockResolvedValue(USER);
    vi.spyOn(adminApi, 'setUserStatus').mockRejectedValue(new AdminApiError('Erreur 502', 502));

    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: /suspendre le compte/i }));

    expect(await screen.findByRole('alert')).toHaveTextContent('Action impossible, réessayez.');
  });

  // Le message du serveur diffère volontairement du texte de la page : c'est
  // le STATUT qui doit décider de la phrase affichée, pas le message reçu.
  it('distingue un compte introuvable (404) d’une fiche indisponible', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'userDetail').mockRejectedValue(new AdminApiError('Not found', 404));

    renderPage();

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('Utilisateur introuvable.');
    expect(alert).not.toHaveTextContent('Fiche indisponible.');
  });

  it('montre toute autre erreur de chargement comme une fiche indisponible', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'userDetail').mockRejectedValue(
      new AdminApiError('Internal server error', 500),
    );

    renderPage();

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('Fiche indisponible.');
    expect(alert).not.toHaveTextContent('Utilisateur introuvable.');
  });

  it('sans jeton, ne rend rien et renvoie vers la connexion', () => {
    vi.spyOn(adminApi, 'userDetail').mockResolvedValue(USER);

    renderPage();

    expect(routerReplace).toHaveBeenCalledWith('/login');
    expect(screen.queryByRole('heading', { name: /fiche utilisateur/i })).not.toBeInTheDocument();
  });

  it('avec un jeton, ne renvoie jamais vers la connexion', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'userDetail').mockResolvedValue(USER);

    renderPage();

    expect(await screen.findByRole('heading', { name: /fiche utilisateur/i })).toBeInTheDocument();
    expect(routerReplace).not.toHaveBeenCalled();
  });
});
