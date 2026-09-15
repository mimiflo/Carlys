import { ADMIN_PERMISSIONS } from '@carlys/api-contracts';
import { fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { EMPTY_PERMISSIONS, adminPermissions, adminToken } from '@/lib/admin-api';
import { AdminShell, firstAllowedRoute } from './admin-shell';

/**
 * Le back-office recevait les permissions de l'administrateur à la connexion
 * et les jetait : la barre de navigation montrait les six entrées à tout le
 * monde, et l'accueil était `/users` pour tout le monde. Un « content-manager »
 * atterrissait donc sur une page qu'il n'a pas le droit de lire, avec un
 * message lui conseillant de se reconnecter — ce qui n'y changeait rien.
 */

const routerReplace = vi.fn();

vi.mock('next/navigation', () => ({
  usePathname: () => '/exercises',
  useRouter: () => ({ replace: routerReplace, push: vi.fn() }),
}));

// Les trois rôles que `ADMIN_ROLES` (apps/api) projette dans la base, recopiés
// ici parce que le back-office ne dépend pas de l'API — seule la liste des
// permissions est partagée, et le rôle « superadmin » EST cette liste.
const SUPER_ADMIN: readonly string[] = ADMIN_PERMISSIONS;
const CONTENT_MANAGER = [
  'exercise:read',
  'exercise:publish',
  'exercise:write',
  'media:read',
  'media:write',
];
const SUPPORT = ['user:read', 'audit:read', 'community:moderate'];

function liens(): string[] {
  return screen
    .getAllByRole('link')
    .map((lien) => lien.textContent ?? '')
    .filter((texte) => texte !== 'Carlys Admin');
}

afterEach(() => {
  routerReplace.mockClear();
  adminToken.clear();
});

describe('firstAllowedRoute', () => {
  it('rend la première entrée que les permissions autorisent RÉELLEMENT', () => {
    expect(firstAllowedRoute(SUPER_ADMIN)).toBe('/users');
    expect(firstAllowedRoute(SUPPORT)).toBe('/users');
    expect(firstAllowedRoute(CONTENT_MANAGER)).toBe('/exercises');
    expect(firstAllowedRoute(['audit:read'])).toBe('/audit');
    expect(firstAllowedRoute(['community:moderate'])).toBe('/reports');
  });

  // Sans permission connue, mieux vaut une page qui répondra 403 en clair
  // qu'une redirection vers nulle part : le serveur reste le juge.
  it('retombe sur /users quand aucune entrée n’est autorisée', () => {
    expect(firstAllowedRoute([])).toBe('/users');
    expect(firstAllowedRoute(['une:permission:inconnue'])).toBe('/users');
  });
});

describe('AdminShell', () => {
  it('ne montre à un content-manager que les pages qu’il peut ouvrir', () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(CONTENT_MANAGER);

    render(<AdminShell title="Exercices">contenu</AdminShell>);

    expect(liens()).toEqual(['Exercices', 'Catégories', 'Médias']);
    expect(screen.queryByRole('link', { name: 'Utilisateurs' })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Signalements' })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Journal d’audit' })).not.toBeInTheDocument();
  });

  it('montre les six entrées à qui a toutes les permissions', () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(SUPER_ADMIN);

    render(<AdminShell title="Utilisateurs">contenu</AdminShell>);

    expect(liens()).toEqual([
      'Utilisateurs',
      'Signalements',
      'Exercices',
      'Catégories',
      'Médias',
      'Journal d’audit',
    ]);
  });

  it('ramène le logo à la première page autorisée, pas à /users', () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(CONTENT_MANAGER);

    render(<AdminShell title="Exercices">contenu</AdminShell>);

    expect(screen.getByRole('link', { name: 'Carlys Admin' })).toHaveAttribute(
      'href',
      '/exercises',
    );
  });

  // Permissions absentes (session ouverte avant cette version) : on ne cache
  // rien d'utile en montrant une barre vide — la page elle-même dira le reste.
  it('sans permissions connues, n’affiche aucune entrée', () => {
    adminToken.set('jeton-admin');

    render(<AdminShell title="Utilisateurs">contenu</AdminShell>);

    expect(liens()).toEqual([]);
    expect(screen.getByText('contenu')).toBeInTheDocument();
  });

  it('la déconnexion efface AUSSI les permissions, pas seulement le jeton', () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(SUPER_ADMIN);

    render(<AdminShell title="Utilisateurs">contenu</AdminShell>);
    fireEvent.click(screen.getByRole('button', { name: 'Se déconnecter' }));

    expect(adminToken.get()).toBeNull();
    expect(adminPermissions.get()).toEqual([]);
    expect(routerReplace).toHaveBeenCalledWith('/login');
  });
});

describe('adminPermissions', () => {
  /**
   * `useSyncExternalStore` compare les instantanés PAR IDENTITÉ. Une lecture
   * qui reconstruit son tableau à chaque appel fait lever React (« The result
   * of getSnapshot should be cached to avoid an infinite loop ») et la
   * coquille ne rend plus rien. Cette égalité de RÉFÉRENCE est donc la
   * garantie, pas une optimisation.
   */
  it('rend la même référence tant que le stockage n’a pas changé', () => {
    adminPermissions.set(SUPER_ADMIN);

    const premier = adminPermissions.get();
    expect(adminPermissions.get()).toBe(premier);

    adminPermissions.set(CONTENT_MANAGER);
    const second = adminPermissions.get();
    expect(second).not.toBe(premier);
    expect(second).toEqual(CONTENT_MANAGER);
    expect(adminPermissions.get()).toBe(second);
  });

  it('traite un stockage corrompu comme une absence, sans lever', () => {
    window.sessionStorage.setItem('carlys-admin-permissions', '{pas du json');
    expect(adminPermissions.get()).toBe(EMPTY_PERMISSIONS);

    window.sessionStorage.setItem('carlys-admin-permissions', '{"user:read":true}');
    expect(adminPermissions.get()).toBe(EMPTY_PERMISSIONS);

    // Un tableau qui mélange des valeurs : seules les chaînes survivent.
    window.sessionStorage.setItem('carlys-admin-permissions', '["user:read",7,null]');
    expect(adminPermissions.get()).toEqual(['user:read']);
  });
});
