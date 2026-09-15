import type { AdminAuditLog } from '@carlys/api-contracts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ADMIN_PERMISSIONS } from '@carlys/api-contracts';
import { adminApi, adminPermissions, adminToken, type Page } from '@/lib/admin-api';
import AuditPage from './page';

/**
 * Le journal répond à « qui a fait quoi, quand, et d'où ». La page en rendait
 * deux : la date et l'action. La colonne « Acteur » n'affichait que le TYPE
 * (`ADMIN`, `USER`), alors que le contrat porte `adminUserId`, `userId` et
 * `ipAddress` depuis toujours — trois enregistrements d'un même type y étaient
 * donc indiscernables.
 */

const PAR_UN_ADMIN: AdminAuditLog = {
  id: '11111111-2222-4333-8444-555555555555',
  actorType: 'ADMIN',
  action: 'admin.user.suspend',
  userId: null,
  adminUserId: 'aaaaaaaa-2222-4333-8444-555555555555',
  resourceType: 'User',
  resourceId: 'bbbbbbbb-2222-4333-8444-555555555555',
  ipAddress: '203.0.113.7',
  metadata: null,
  createdAt: '2026-09-01T10:00:00.000Z',
};

const PAR_UN_MEMBRE: AdminAuditLog = {
  ...PAR_UN_ADMIN,
  id: '22222222-2222-4333-8444-555555555555',
  actorType: 'USER',
  action: 'auth.login',
  userId: 'cccccccc-2222-4333-8444-555555555555',
  adminUserId: null,
  resourceType: null,
  resourceId: null,
  ipAddress: '198.51.100.4',
};

/** Événement du système : ni admin, ni membre, et souvent sans adresse. */
const PAR_LE_SYSTEME: AdminAuditLog = {
  ...PAR_UN_ADMIN,
  id: '33333333-2222-4333-8444-555555555555',
  actorType: 'SYSTEM',
  action: 'subscription.webhook',
  userId: null,
  adminUserId: null,
  resourceType: null,
  resourceId: null,
  ipAddress: null,
};

function pageOf(items: AdminAuditLog[]): Page<AdminAuditLog> {
  return { items, nextCursor: null, hasMore: false };
}

vi.mock('next/navigation', () => ({
  usePathname: () => '/audit',
  useRouter: () => ({ replace: vi.fn(), push: vi.fn() }),
}));

function renderPage() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <AuditPage />
    </QueryClientProvider>,
  );
}

afterEach(() => {
  vi.restoreAllMocks();
  adminToken.clear();
});

describe('Page Journal d’audit', () => {
  it('nomme l’acteur, son identifiant et l’adresse d’origine', async () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(ADMIN_PERMISSIONS);
    vi.spyOn(adminApi, 'auditLogs').mockResolvedValue(
      pageOf([PAR_UN_ADMIN, PAR_UN_MEMBRE, PAR_LE_SYSTEME]),
    );

    renderPage();

    await screen.findByText('admin.user.suspend');
    const rows = screen.getAllByRole('row');
    // En-tête + trois événements.
    expect(rows).toHaveLength(4);

    const parAdmin = within(rows[1] as HTMLElement);
    expect(parAdmin.getByText('Administration')).toBeInTheDocument();
    expect(parAdmin.getByText(PAR_UN_ADMIN.adminUserId as string)).toBeInTheDocument();
    expect(parAdmin.getByText('203.0.113.7')).toBeInTheDocument();

    // Un membre : c'est `userId` qu'il faut lire, pas `adminUserId`.
    const parMembre = within(rows[2] as HTMLElement);
    expect(parMembre.getByText('Membre')).toBeInTheDocument();
    expect(parMembre.getByText(PAR_UN_MEMBRE.userId as string)).toBeInTheDocument();
    expect(parMembre.getByText('198.51.100.4')).toBeInTheDocument();

    // Le système n'a ni identité ni adresse : un tiret, pas une case vide.
    const parSysteme = within(rows[3] as HTMLElement);
    expect(parSysteme.getByText('Système')).toBeInTheDocument();
    expect(parSysteme.getAllByText('—')).toHaveLength(3);
  });

  it('dit « Aucun événement » sur un journal vide, sur toute la largeur', async () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(ADMIN_PERMISSIONS);
    vi.spyOn(adminApi, 'auditLogs').mockResolvedValue(pageOf([]));

    renderPage();

    const vide = await screen.findByText('Aucun événement.');
    // Cinq colonnes d'en-tête : le message doit toutes les couvrir.
    expect(vide).toHaveAttribute('colspan', String(screen.getAllByRole('columnheader').length));
  });

  it('montre le refus de permission comme tel', async () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(ADMIN_PERMISSIONS);
    vi.spyOn(adminApi, 'auditLogs').mockRejectedValue(new Error('403'));

    renderPage();

    expect(await screen.findByRole('alert')).toHaveTextContent('audit:read');
  });
});
