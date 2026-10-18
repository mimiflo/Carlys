import type { AdminCommunityReport } from '@carlys/api-contracts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiError, adminApi, adminPermissions, adminToken, type Page } from '@/lib/admin-api';
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
  friendChallengeId: null,
  reason: 'HARCELEMENT',
  details: 'Il insiste après mon refus.',
  status: 'OPEN',
  createdAt: '2026-09-01T10:00:00.000Z',
  resolvedAt: null,
  reporter: REPORTER,
  reportedUser: REPORTED,
  encouragementMessage: 'Réponds-moi.',
  friendChallengeTitle: null,
  friendChallengeMessage: null,
  friendChallengeMessageRemoved: false,
  resolvedBy: null,
  resolutionNote: null,
  contentRemoved: false,
  userSuspended: false,
  reportedUserStatus: 'ACTIVE',
  reportedUserReportsCount: 1,
  reportedUserOpenReportsCount: 1,
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

/** Défi entre amis signalé : son titre et le mot de son créateur, figés. */
const REPORT_CHALLENGE: AdminCommunityReport = {
  ...REPORT,
  id: 'aaaaaaaa-2222-4333-8444-555555555555',
  encouragementId: null,
  encouragementMessage: null,
  friendChallengeId: '44444444-2222-4333-8444-555555555555',
  friendChallengeTitle: 'Qui court le plus',
  friendChallengeMessage: 'Tu vas encore perdre, comme d’habitude.',
  reason: 'CONTENU_INAPPROPRIE',
  details: null,
};

/** Défi dont le créateur n'avait écrit aucun mot : c'est le titre qui est visé. */
const REPORT_CHALLENGE_NO_MESSAGE: AdminCommunityReport = {
  ...REPORT_CHALLENGE,
  id: 'bbbbbbbb-2222-4333-8444-555555555555',
  friendChallengeTitle: 'Dix séances',
  friendChallengeMessage: null,
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
    expect(list).toHaveBeenCalledWith('OPEN', undefined, {});

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

  it('montre le défi visé : son titre, puis le mot cité du créateur', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([REPORT_CHALLENGE]));

    renderPage();

    expect(await screen.findByText('Défi « Qui court le plus »')).toBeInTheDocument();
    const quoted = screen.getByText('Tu vas encore perdre, comme d’habitude.');
    expect(quoted.tagName).toBe('Q');
    expect(within(screen.getByRole('table')).getByText('Contenu inapproprié')).toBeInTheDocument();
    // Un défi n'est ni « la personne en général » ni un encouragement.
    expect(screen.queryByText('La personne en général')).not.toBeInTheDocument();
    expect(screen.queryByText('(sans message)')).not.toBeInTheDocument();
  });

  it('dit « (sans message) » quand le défi visé n’en portait pas', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(
      pageOf([REPORT_CHALLENGE_NO_MESSAGE, REPORT]),
    );

    renderPage();

    const rows = await screen.findAllByRole('row');
    const challengeRow = within(rows[1] as HTMLElement);
    expect(challengeRow.getByText('Défi « Dix séances »')).toBeInTheDocument();
    expect(challengeRow.getByText('(sans message)')).toBeInTheDocument();
    // Le cliché d'encouragement de la ligne voisine reste à sa place.
    expect(within(rows[2] as HTMLElement).getByText('Réponds-moi.')).toBeInTheDocument();
    expect(within(rows[2] as HTMLElement).queryByText(/^Défi/)).not.toBeInTheDocument();
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

  // Vingt signalements par page, deux parties chacun : l'adresse affichée par
  // défaut, c'était quatre-vingts adresses à l'écran d'une file où le seul
  // geste est « Résoudre ». Elle reste accessible, sur intention.
  it('n’affiche PAS l’e-mail de qui porte déjà un nom — il passe en infobulle', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([REPORT]));

    renderPage();

    const auteur = await screen.findByRole('link', { name: 'Membre' });
    expect(screen.queryByText(REPORTER.email)).not.toBeInTheDocument();
    expect(auteur).toHaveAttribute('title', REPORTER.email);

    // Sans nom, l'e-mail reste le libellé : c'est le repli, et il tient.
    expect(screen.getByRole('link', { name: REPORTED.email })).toBeInTheDocument();
  });

  it('classe sans suite depuis la fiche, puis recharge la liste', async () => {
    adminToken.set('jeton-admin');
    const list = vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([REPORT]));
    const decide = vi
      .spyOn(adminApi, 'decideCommunityReport')
      .mockResolvedValue({ ...REPORT, status: 'RESOLVED', resolvedAt: '2026-09-02T08:00:00.000Z' });

    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'Examiner' }));
    fireEvent.click(screen.getByRole('button', { name: 'Classer sans suite' }));

    await waitFor(() => {
      expect(decide).toHaveBeenCalledWith(REPORT.id, { removeContent: false, suspendUser: false });
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

    fireEvent.click(await screen.findByRole('button', { name: 'Voir la décision' }));
    expect(screen.getByText(/résolu le/i)).toBeInTheDocument();
    expect(screen.getByText('Classé sans suite')).toBeInTheDocument();
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
    expect(list).toHaveBeenLastCalledWith('RESOLVED', undefined, {});

    fireEvent.click(screen.getByRole('radio', { name: 'Tous' }));
    expect(await screen.findByText('Aucun signalement.')).toBeInTheDocument();
    expect(list).toHaveBeenLastCalledWith(undefined, undefined, {});
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
      expect(list).toHaveBeenLastCalledWith('OPEN', REPORT.id, {});
    });
    const table = within(await screen.findByRole('table'));
    expect(await table.findByText('Spam')).toBeInTheDocument();
    expect(table.getByText('Harcèlement')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Charger la suite' })).not.toBeInTheDocument();
  });

  it('montre un refus de permission (403) comme tel, pas comme une panne', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'listCommunityReports').mockRejectedValue(
      new ApiError('Permission community:moderate requise.', 403),
    );

    renderPage();

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('community:moderate');
    expect(alert).not.toHaveTextContent('reconnectez-vous');
  });

  // Un 502 conseillait de « se reconnecter », ce qui n'y changeait rien : la
  // session n'y était pour rien.
  it('montre toute autre erreur de chargement comme une panne passagère', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'listCommunityReports').mockRejectedValue(new ApiError('Erreur 502', 502));

    renderPage();

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('Signalements indisponibles pour le moment.');
    expect(alert).not.toHaveTextContent(/reconnect/);
  });

  it('montre un refus de décision (403) dans la fiche, sans casser la liste', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([REPORT]));
    vi.spyOn(adminApi, 'decideCommunityReport').mockRejectedValue(
      new ApiError('Permission community:moderate requise.', 403),
    );

    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'Examiner' }));
    fireEvent.click(screen.getByRole('button', { name: 'Classer sans suite' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('Permission manquante');
    expect(within(screen.getByRole('table')).getByText('Harcèlement')).toBeInTheDocument();
  });

  // Le support traite les signalements sans pouvoir suspendre : la fiche le
  // dit au lieu de proposer un geste toujours refusé.
  it('avec user:update, la suspension est proposée depuis la fiche', async () => {
    adminToken.set('jeton-admin');
    adminPermissions.set(['user:read', 'user:update', 'community:moderate']);
    vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([REPORT]));

    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'Examiner' }));

    expect(screen.getByRole('checkbox', { name: /Suspendre le compte/ })).toBeEnabled();
  });

  // Sans jeton, la coquille et son titre seuls (le pré-rendu les peint) :
  // ni contenu, ni requête qui partirait en 401.
  it('sans jeton, ne demande ni ne rend aucun signalement et renvoie vers la connexion', () => {
    const list = vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([]));

    renderPage();

    expect(routerReplace).toHaveBeenCalledWith('/login');
    expect(screen.getByRole('heading', { level: 1, name: /signalements/i })).toBeInTheDocument();
    expect(screen.queryByRole('table')).not.toBeInTheDocument();
    expect(list).not.toHaveBeenCalled();
  });

  describe('décision', () => {
    function ouvrir(report: AdminCommunityReport, permissions: string[]) {
      adminToken.set('jeton-admin');
      adminPermissions.set(permissions);
      vi.spyOn(adminApi, 'listCommunityReports').mockResolvedValue(pageOf([report]));
      renderPage();
    }

    it('retirer le contenu et suspendre, avec la note exigée pour la suspension', async () => {
      ouvrir(REPORT, ['community:moderate', 'user:update']);
      const decide = vi
        .spyOn(adminApi, 'decideCommunityReport')
        .mockResolvedValue({ ...REPORT, status: 'RESOLVED' });
      fireEvent.click(await screen.findByRole('button', { name: 'Examiner' }));

      fireEvent.click(screen.getByRole('checkbox', { name: /Retirer l’encouragement/ }));
      fireEvent.click(screen.getByRole('checkbox', { name: /Suspendre le compte/ }));
      const appliquer = screen.getByRole('button', { name: 'Appliquer la décision' });
      expect(appliquer).toBeDisabled();

      fireEvent.change(screen.getByLabelText(/Note de décision/), {
        target: { value: 'Récidive de harcèlement.' },
      });
      fireEvent.click(appliquer);
      await waitFor(() => {
        expect(decide).toHaveBeenCalledWith(REPORT.id, {
          removeContent: true,
          suspendUser: true,
          note: 'Récidive de harcèlement.',
        });
      });
    });

    it('sans user:update, la suspension est expliquée et indisponible', async () => {
      ouvrir(REPORT, ['community:moderate']);
      fireEvent.click(await screen.findByRole('button', { name: 'Examiner' }));
      expect(screen.getByRole('checkbox', { name: /Suspendre le compte/ })).toBeDisabled();
      expect(screen.getByText(/Demande la permission user:update/)).toBeInTheDocument();
    });

    it('rien à retirer quand le signalement vise la personne en général', async () => {
      ouvrir(REPORT_ABOUT_PERSON, ['community:moderate']);
      fireEvent.click(await screen.findByRole('button', { name: 'Examiner' }));
      expect(screen.getByRole('checkbox', { name: /Retirer/ })).toBeDisabled();
    });

    it('l’historique d’une récidive filtre la liste sur la personne visée', async () => {
      const recidive = { ...REPORT, reportedUserReportsCount: 4, reportedUserOpenReportsCount: 2 };
      ouvrir(recidive, ['community:moderate']);
      const list = vi.mocked(adminApi.listCommunityReports);
      fireEvent.click(await screen.findByRole('button', { name: 'Examiner' }));
      fireEvent.click(screen.getByRole('button', { name: 'Voir ses 4 signalements' }));

      await waitFor(() => {
        expect(list).toHaveBeenLastCalledWith(undefined, undefined, {
          reportedUserId: REPORTED.id,
        });
      });
      expect(screen.getByText(/Signalements visant/)).toBeInTheDocument();
    });
  });
});
