import type { AdminCommunityReport } from '@carlys/api-contracts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AdminApiError, adminApi, adminToken, type Page } from '@/lib/admin-api';
import ReportsPage from './page';

const REPORTER = {
  id: '11111111-2222-4333-8444-555555555555',
  email: 'membre@carlys.test',
  displayName: 'Membre',
};
const REPORTED = {
  id: '22222222-2222-4333-8444-555555555555',
  email: 'vise@carlys.test',
  displayName: null,
};

const REPORT: AdminCommunityReport = {
  id: '77777777-2222-4333-8444-555555555555',
  reportedUserId: REPORTED.id,
  encouragementId: '33333333-2222-4333-8444-555555555555',
  reason: 'HARCELEMENT',
  details: 'Il insiste après mon refus.',
  status: 'OPEN',
  createdAt: '2026-09-01T10:00:00.000Z',
  resolvedAt: null,
  reporter: REPORTER,
  reportedUser: REPORTED,
  encouragementMessage: 'Réponds-moi.',
};

const REPORT_ABOUT_PERSON: AdminCommunityReport = {
  ...REPORT,
  id: '88888888-2222-4333-8444-555555555555',
  encouragementId: null,
  encouragementMessage: null,
  reason: 'SPAM',
  details: null,
};

/** Message retiré APRÈS le signalement : l'identifiant part, le cliché reste. */
const REPORT_MESSAGE_REMOVED: AdminCommunityReport = {
  ...REPORT,
  id: '99999999-2222-4333-8444-555555555555',
  encouragementId: null,
  encouragementMessage: 'Tu ne vaux rien.',
};

function pageOf(
  items: AdminCommunityReport[],
  nextCursor: string | null = null,
): Page<AdminCommunityReport> {
  return { items, nextCursor, hasMore: nextCursor !== null };
}

const routerReplace = vi.fn();

// Hors de Next, la coquille et les liens n'ont pas de routeur : on en fournit un.
vi.mock('next/navigation', () => ({
  usePathname: () => '/reports',
  useRouter: () => ({ replace: routerReplace, push: vi.fn() }),
}));

/** Sans nouvelle tentative : un échec doit se voir tout de suite, pas après un délai. */
function renderPage() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>
      <ReportsPage />
    </QueryClientProvider>,
  );
}

afterEach(() => {
  vi.restoreAllMocks();
  routerReplace.mockClear();
  adminToken.clear();
});

describe('Page Signalements', () => {
  it('liste les signalements OUVERTS par défaut, avec motif, personnes et texte visé', async () => {
    adminToken.set('jeton-admin');
    const list = vi
      .spyOn(adminApi, 'listCommunityReports')
      .mockResolvedValue(pageOf([REPORT, REPORT_ABOUT_PERSON]));

    renderPage();

    const rows = await screen.findAllByRole('row');
    // Une ligne d'en-tête, puis une par signalement.
    expect(rows).toHaveLength(3);
    expect(list).toHaveBeenCalledWith('OPEN', undefined);

    const first = within(rows[1] as HTMLElement);
    expect(first.getByText('Harcèlement')).toBeInTheDocument();
    expect(first.getByText('Il insiste après mon refus.')).toBeInTheDocument();
    expect(first.getByText('Réponds-moi.')).toBeInTheDocument();

    // Le message est toujours dans le fil : rien ne parle d'un retrait.
    expect(first.queryByText('Message retiré depuis')).not.toBeInTheDocument();

    const second = within(rows[2] as HTMLElement);
    expect(second.getByText('Spam')).toBeInTheDocument();
    expect(second.getByText('La personne en général')).toBeInTheDocument();
  });

  it('montre le cliché d’un message retiré depuis, et le dit', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([REPORT_MESSAGE_REMOVED]));

    renderPage();

    // La preuve figée au signalement survit à la suppression du message.
    expect(await screen.findByText('Tu ne vaux rien.')).toBeInTheDocument();
    expect(screen.getByText('Message retiré depuis')).toBeInTheDocument();
    expect(screen.queryByText('La personne en général')).not.toBeInTheDocument();
  });

  it('dit « La personne en général » quand aucun message n’est visé', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([REPORT_ABOUT_PERSON]));

    renderPage();

    expect(await screen.findByText('La personne en général')).toBeInTheDocument();
    expect(screen.queryByText('Message retiré depuis')).not.toBeInTheDocument();
  });

  it('lie l’auteur et la personne visée à leur fiche, l’e-mail suppléant un nom absent', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([REPORT]));

    renderPage();

    expect(await screen.findByRole('link', { name: 'Membre' })).toHaveAttribute(
      'href',
      `/users/${REPORTER.id}`,
    );
    expect(screen.getByRole('link', { name: REPORTED.email })).toHaveAttribute(
      'href',
      `/users/${REPORTED.id}`,
    );
  });

  it('résout un signalement, puis recharge la liste', async () => {
    adminToken.set('jeton-admin');
    const list = vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([REPORT]));
    const setStatus = vi
      .spyOn(adminApi, 'setCommunityReportStatus')
      .mockResolvedValue({ ...REPORT, status: 'RESOLVED', resolvedAt: '2026-09-02T08:00:00.000Z' });

    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'Résoudre' }));

    await waitFor(() => {
      expect(setStatus).toHaveBeenCalledWith(REPORT.id, 'RESOLVED');
    });
    await waitFor(() => {
      expect(list).toHaveBeenCalledTimes(2);
    });
  });

  it('rouvre un signalement résolu, en montrant sa date de résolution', async () => {
    adminToken.set('jeton-admin');
    const resolved: AdminCommunityReport = {
      ...REPORT,
      status: 'RESOLVED',
      resolvedAt: '2026-09-02T08:00:00.000Z',
    };
    vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([resolved]));
    const setStatus = vi.spyOn(adminApi, 'setCommunityReportStatus').mockResolvedValue(REPORT);

    renderPage();
    fireEvent.click(screen.getByRole('radio', { name: 'Résolus' }));

    expect(await screen.findByText(/résolu le/i)).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Rouvrir' }));

    await waitFor(() => {
      expect(setStatus).toHaveBeenCalledWith(REPORT.id, 'OPEN');
    });
  });

  it('change de filtre : Résolus puis Tous interrogent le serveur avec ce statut', async () => {
    adminToken.set('jeton-admin');
    const list = vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([]));

    renderPage();
    expect(await screen.findByText('Aucun signalement ouvert.')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('radio', { name: 'Résolus' }));
    expect(await screen.findByText('Aucun signalement résolu.')).toBeInTheDocument();
    expect(list).toHaveBeenLastCalledWith('RESOLVED', undefined);

    fireEvent.click(screen.getByRole('radio', { name: 'Tous' }));
    expect(await screen.findByText('Aucun signalement.')).toBeInTheDocument();
    expect(list).toHaveBeenLastCalledWith(undefined, undefined);
  });

  it('charge la suite avec le curseur rendu par la page précédente', async () => {
    adminToken.set('jeton-admin');
    const list = vi
      .spyOn(adminApi, 'listCommunityReports')
      .mockResolvedValueOnce(pageOf([REPORT], REPORT.id))
      .mockResolvedValueOnce(pageOf([REPORT_ABOUT_PERSON]));

    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'Charger la suite' }));

    await waitFor(() => {
      expect(list).toHaveBeenLastCalledWith('OPEN', REPORT.id);
    });
    expect(await screen.findByText('Spam')).toBeInTheDocument();
    expect(screen.getByText('Harcèlement')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Charger la suite' })).not.toBeInTheDocument();
  });

  it('montre un refus de permission (403) comme tel, pas comme une panne', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'listCommunityReports').mockRejectedValue(
      new AdminApiError('Permission community:moderate requise.', 403),
    );

    renderPage();

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('community:moderate');
    expect(alert).not.toHaveTextContent('reconnectez-vous');
  });

  it('montre toute autre erreur de chargement comme une liste indisponible', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'listCommunityReports').mockRejectedValue(
      new AdminApiError('Erreur 502', 502),
    );

    renderPage();

    expect(await screen.findByRole('alert')).toHaveTextContent('reconnectez-vous');
  });

  it('montre un refus de résolution (403) sur la ligne, sans casser la liste', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([REPORT]));
    vi.spyOn(adminApi, 'setCommunityReportStatus').mockRejectedValue(
      new AdminApiError('Permission community:moderate requise.', 403),
    );

    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'Résoudre' }));

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Permission manquante pour cette action.',
    );
    expect(screen.getByText('Harcèlement')).toBeInTheDocument();
  });

  // Comme sur les autres pages, la requête part quand même : le vrai garde
  // est côté serveur (401 sans jeton), la coquille ne fait que ne rien montrer.
  it('sans jeton, ne rend rien et renvoie vers la connexion', () => {
    vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([]));

    renderPage();

    expect(routerReplace).toHaveBeenCalledWith('/login');
    expect(screen.queryByRole('heading', { name: /signalements/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
  });
});
