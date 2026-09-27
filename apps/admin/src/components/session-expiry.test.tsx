import { ADMIN_PERMISSIONS } from '@carlys/api-contracts';
import { screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import AuditPage from '@/app/audit/page';
import MediaPage from '@/app/media/page';
import { adminPermissions, adminToken } from '@/lib/admin-api';
import { renderWithQuery } from '@/testing/fixtures';

/**
 * Une page du back-office ouverte avec un jeton que le serveur refuse (401 :
 * expiré au bout de douze heures, ou compte désactivé) renvoie vers la
 * connexion. Elle affichait « la permission audit:read est requise » et
 * restait là : il fallait trouver « Se déconnecter » soi-même.
 *
 * Le test passe par le VRAI client (seul `fetch` est simulé) : c'est lui qui
 * oublie le jeton, et la coquille qui l'écoute.
 */

const routerReplace = vi.fn();

vi.mock('next/navigation', () => ({
  usePathname: () => '/audit',
  useRouter: () => ({ replace: routerReplace, push: vi.fn() }),
}));

function repondre(status: number): Response {
  return new Response(
    JSON.stringify({
      error: { code: 'X', message: 'Jeton invalide.', details: [], requestId: 'r' },
    }),
    { status, headers: { 'Content-Type': 'application/json' } },
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
  routerReplace.mockClear();
  adminToken.clear();
});

describe('session expirée sur une page du back-office', () => {
  it('un 401 renvoie vers la connexion et ne laisse rien à l’écran', async () => {
    adminToken.set('jeton-perime');
    adminPermissions.set(ADMIN_PERMISSIONS);
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(repondre(401)));

    renderWithQuery(<AuditPage />);
    expect(screen.getByRole('heading', { name: 'Journal d’audit' })).toBeInTheDocument();

    await waitFor(() => expect(routerReplace).toHaveBeenCalledWith('/login'));
    expect(adminToken.wasExpired()).toBe(true);
    expect(screen.queryByRole('heading', { name: 'Journal d’audit' })).not.toBeInTheDocument();
    expect(screen.queryByText(/permission audit:read/)).not.toBeInTheDocument();
  });

  it('une panne réseau n’est ni une fin de session ni un refus de permission', async () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(ADMIN_PERMISSIONS);
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')));

    renderWithQuery(<MediaPage />);

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('Bibliothèque indisponible : le serveur ne répond pas.');
    expect(alert).not.toHaveTextContent('permission');
    expect(routerReplace).not.toHaveBeenCalled();
    expect(adminToken.get()).toBe('jeton-admin');
  });
});
