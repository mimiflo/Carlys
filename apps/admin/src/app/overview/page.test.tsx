import { ADMIN_PERMISSIONS } from '@carlys/api-contracts';
import { QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { adminApi, adminPermissions, adminToken } from '@/lib/admin-api';
import { renderWithQuery, testQueryClient } from '@/testing/fixtures';
import ReportsPage from '../reports/page';
import OverviewPage from './page';

/**
 * La vue d'ensemble : chaque bloc ne paraît qu'à qui peut le lire, et les
 * chiffres clés sont les vrais.
 */
vi.mock('next/navigation', () => ({
  usePathname: () => '/overview',
  useRouter: () => ({ replace: vi.fn(), push: vi.fn() }),
}));

const OVERVIEW = {
  usersCount: 1284,
  premiumUsersCount: 317,
  workoutSessionsCount: 18452,
  completedWorkoutSessionsCount: 16903,
  exercisesCount: 186,
  publishedExercisesCount: 171,
};

beforeEach(() => {
  vi.spyOn(adminApi, 'overview').mockResolvedValue(OVERVIEW);
  vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue({
    items: [],
    nextCursor: null,
    hasMore: false,
  });
  vi.spyOn(adminApi, 'auditLogs').mockResolvedValue({
    items: [],
    nextCursor: null,
    hasMore: false,
  });
  vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')));
  adminToken.set('jeton-admin');
});

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  adminToken.clear();
});

describe('OverviewPage', () => {
  it('affiche les chiffres clés et leur part', async () => {
    adminPermissions.set(ADMIN_PERMISSIONS);
    renderWithQuery(<OverviewPage />);

    expect(await screen.findByText('1 284')).toBeInTheDocument();
    expect(screen.getByText('25 % des comptes')).toBeInTheDocument();
    expect(screen.getByText('Signalements à traiter')).toBeInTheDocument();
    expect(screen.getByText('Dernières actions')).toBeInTheDocument();
  });

  it('masque la modération et le journal à qui ne peut pas les lire', async () => {
    adminPermissions.set(['user:read']);
    renderWithQuery(<OverviewPage />);

    expect(await screen.findByText('1 284')).toBeInTheDocument();
    expect(screen.queryByText('Signalements à traiter')).not.toBeInTheDocument();
    expect(screen.queryByText('Dernières actions')).not.toBeInTheDocument();
    expect(adminApi.listCommunityReports).not.toHaveBeenCalled();
    expect(adminApi.auditLogs).not.toHaveBeenCalled();
  });

  it('une erreur se dit : ni « 0 » signalement ni journal vide', async () => {
    adminPermissions.set(ADMIN_PERMISSIONS);
    vi.mocked(adminApi.listCommunityReports).mockRejectedValue(new Error('panne'));
    vi.mocked(adminApi.auditLogs).mockRejectedValue(new Error('panne'));
    renderWithQuery(<OverviewPage />);

    expect(await screen.findByText(/Signalements indisponibles/)).toBeInTheDocument();
    expect(await screen.findByText(/Journal indisponible/)).toBeInTheDocument();
    expect(screen.queryByText('Aucun événement pour le moment.')).not.toBeInTheDocument();
  });

  // Le compteur et la liste paginée de la page Signalements partageaient la
  // même clé de cache avec deux formes de données : passer de l'une à
  // l'autre faisait planter la seconde.
  it('la page Signalements s’ouvre après la vue d’ensemble, sur le même cache', async () => {
    adminPermissions.set(ADMIN_PERMISSIONS);
    const client = testQueryClient();
    const { unmount } = render(
      <QueryClientProvider client={client}>
        <OverviewPage />
      </QueryClientProvider>,
    );
    expect(await screen.findByText('Signalements à traiter')).toBeInTheDocument();
    unmount();

    render(
      <QueryClientProvider client={client}>
        <ReportsPage />
      </QueryClientProvider>,
    );
    expect(await screen.findByText('Aucun signalement ouvert.')).toBeInTheDocument();
  });
});
