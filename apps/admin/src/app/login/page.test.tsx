import type { AdminLoginResult, AdminPermission } from '@carlys/api-contracts';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AdminApiError, adminApi, adminPermissions, adminToken } from '@/lib/admin-api';
import LoginPage from './page';

/**
 * La connexion gardait le jeton et JETAIT les permissions que la même réponse
 * porte, puis envoyait tout le monde sur `/users`. Un « content-manager », qui
 * n'a pas `user:read`, arrivait sur une page qu'il ne peut pas charger.
 */

const routerReplace = vi.fn();

vi.mock('next/navigation', () => ({
  usePathname: () => '/login',
  useRouter: () => ({ replace: routerReplace, push: vi.fn() }),
}));

function resultat(permissions: AdminPermission[]): AdminLoginResult {
  return {
    accessToken: 'jeton-admin',
    expiresInSeconds: 900,
    admin: {
      id: '11111111-2222-4333-8444-555555555555',
      email: 'admin@carlys.test',
      displayName: 'Admin',
      roles: ['content-manager'],
      permissions,
    },
  };
}

function connecte(): void {
  fireEvent.change(screen.getByLabelText('Adresse e-mail'), {
    target: { value: 'admin@carlys.test' },
  });
  fireEvent.change(screen.getByLabelText('Mot de passe'), {
    target: { value: 'motdepasse123' },
  });
  fireEvent.click(screen.getByRole('button', { name: 'Se connecter' }));
}

afterEach(() => {
  vi.restoreAllMocks();
  routerReplace.mockClear();
  adminToken.clear();
});

describe('Page Connexion', () => {
  it('garde les permissions reçues et ouvre la première page autorisée', async () => {
    vi.spyOn(adminApi, 'login').mockResolvedValue(
      resultat(['exercise:read', 'exercise:write', 'media:read', 'media:write']),
    );

    render(<LoginPage />);
    connecte();

    await waitFor(() => {
      expect(routerReplace).toHaveBeenCalledWith('/exercises');
    });
    expect(adminToken.get()).toBe('jeton-admin');
    expect(adminPermissions.get()).toEqual([
      'exercise:read',
      'exercise:write',
      'media:read',
      'media:write',
    ]);
  });

  // Contre-épreuve : le même code doit toujours rendre `/users` à qui y a droit,
  // sans quoi la règle « première page autorisée » serait une redirection en dur
  // déplacée ailleurs.
  it('envoie sur /users l’administrateur qui peut lire les comptes', async () => {
    vi.spyOn(adminApi, 'login').mockResolvedValue(resultat(['user:read', 'audit:read']));

    render(<LoginPage />);
    connecte();

    await waitFor(() => {
      expect(routerReplace).toHaveBeenCalledWith('/users');
    });
  });

  it('distingue un mot de passe faux d’une API injoignable', async () => {
    const login = vi
      .spyOn(adminApi, 'login')
      .mockRejectedValueOnce(new AdminApiError('Identifiants invalides.', 401))
      .mockRejectedValueOnce(new AdminApiError('Échec réseau', 0));

    render(<LoginPage />);
    connecte();
    expect(await screen.findByRole('alert')).toHaveTextContent('E-mail ou mot de passe incorrect.');

    connecte();
    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('l’API est démarrée');
    });

    expect(login).toHaveBeenCalledTimes(2);
    expect(routerReplace).not.toHaveBeenCalled();
    expect(adminToken.get()).toBeNull();
  });
});
