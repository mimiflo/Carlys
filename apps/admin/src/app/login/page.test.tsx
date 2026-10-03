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

const DEFI_CODE = { challengeToken: 'defi' } as const;

async function saisitCode(code = '123456'): Promise<void> {
  fireEvent.change(await screen.findByLabelText('Code à 6 chiffres'), {
    target: { value: code },
  });
  fireEvent.click(screen.getByRole('button', { name: 'Valider' }));
}

afterEach(() => {
  vi.restoreAllMocks();
  routerReplace.mockClear();
  adminToken.clear();
});

describe('Page Connexion', () => {
  // Renvoyé ici par un 401 (jeton expiré, compte désactivé) : la page le dit,
  // sinon elle surgit sans explication au milieu d'une tâche.
  it('annonce une session expirée quand le serveur a refusé le jeton', () => {
    adminToken.expire();

    render(<LoginPage />);

    expect(screen.getByRole('status')).toHaveTextContent('Ta session a expiré');
  });

  it('le mot de passe juste N’OUVRE PAS la session : il demande le code', async () => {
    vi.spyOn(adminApi, 'login').mockResolvedValue(DEFI_CODE);
    const verify = vi.spyOn(adminApi, 'verifyTotp');

    render(<LoginPage />);
    connecte();

    expect(await screen.findByLabelText('Code à 6 chiffres')).toBeInTheDocument();
    expect(adminToken.get()).toBeNull();
    expect(routerReplace).not.toHaveBeenCalled();
    expect(verify).not.toHaveBeenCalled();
  });

  it('2FA pas encore émise : la commande de l’opérateur, aucune étape de code', async () => {
    vi.spyOn(adminApi, 'login').mockRejectedValue(
      new AdminApiError('Double authentification pas encore configurée pour ce compte.', 403),
    );

    render(<LoginPage />);
    connecte();

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Double authentification pas encore configurée',
    );
    expect(screen.queryByLabelText('Code à 6 chiffres')).not.toBeInTheDocument();
  });

  it('code faux : la phrase du serveur, le champ vidé, aucune session', async () => {
    vi.spyOn(adminApi, 'login').mockResolvedValue(DEFI_CODE);
    vi.spyOn(adminApi, 'verifyTotp').mockRejectedValue(
      new AdminApiError('Code incorrect ou déjà utilisé.', 401),
    );

    render(<LoginPage />);
    connecte();
    await saisitCode('000000');

    expect(await screen.findByRole('alert')).toHaveTextContent('Code incorrect ou déjà utilisé.');
    expect(screen.getByLabelText('Code à 6 chiffres')).toHaveValue('');
    expect(adminToken.get()).toBeNull();
  });

  it('n’annonce rien à qui arrive simplement pour se connecter', () => {
    render(<LoginPage />);

    expect(screen.queryByRole('status')).not.toBeInTheDocument();
  });

  it('garde les permissions reçues et ouvre la première page autorisée', async () => {
    vi.spyOn(adminApi, 'login').mockResolvedValue(DEFI_CODE);
    vi.spyOn(adminApi, 'verifyTotp').mockResolvedValue(
      resultat(['exercise:read', 'exercise:write', 'media:read', 'media:write']),
    );

    render(<LoginPage />);
    connecte();
    await saisitCode();

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
    vi.spyOn(adminApi, 'login').mockResolvedValue(DEFI_CODE);
    vi.spyOn(adminApi, 'verifyTotp').mockResolvedValue(resultat(['user:read', 'audit:read']));

    render(<LoginPage />);
    connecte();
    await saisitCode();

    await waitFor(() => {
      expect(routerReplace).toHaveBeenCalledWith('/users');
    });
  });

  // Un serveur injoignable, c'est `fetch` qui rejette (TypeError), pas une
  // réponse de l'API.
  it('distingue un mot de passe faux d’un serveur injoignable', async () => {
    const login = vi
      .spyOn(adminApi, 'login')
      .mockRejectedValueOnce(new AdminApiError('Identifiants invalides.', 401))
      .mockRejectedValueOnce(new TypeError('Failed to fetch'));

    render(<LoginPage />);
    connecte();
    expect(await screen.findByRole('alert')).toHaveTextContent('E-mail ou mot de passe incorrect.');

    connecte();
    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(
        'Connexion impossible pour le moment : le serveur ne répond pas. Réessaie dans un instant.',
      );
    });

    expect(login).toHaveBeenCalledTimes(2);
    expect(routerReplace).not.toHaveBeenCalled();
    expect(adminToken.get()).toBeNull();
  });

  /**
   * Tout ce qui n'était pas un 401 conseillait de « vérifier que l'API est
   * démarrée » : une consigne de développeur, en production, au vouvoiement,
   * et fausse pour un compte verrouillé après trop d'essais.
   */
  it.each([
    [429, 'Trop de tentatives : patiente quelques minutes avant de réessayer.'],
    [502, 'Connexion impossible pour le moment. Réessaie dans un instant.'],
  ])('un refus %i se dit par sa cause, sans consigne de développeur', async (status, message) => {
    vi.spyOn(adminApi, 'login').mockRejectedValue(new AdminApiError('Refus.', status));

    render(<LoginPage />);
    connecte();

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent(message);
    expect(alert).not.toHaveTextContent(/API|vérifiez/);
  });
});
