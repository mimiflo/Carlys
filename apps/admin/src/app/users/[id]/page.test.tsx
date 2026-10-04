import type { ManagedEntitlement, ManagedUserDetail } from '@carlys/api-contracts';
import {
  ADMIN_PERMISSIONS,
  ENTITLEMENT_KEYS,
  PREMIUM_ENTITLEMENT_KEYS,
} from '@carlys/api-contracts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiError, adminApi, adminPermissions, adminToken } from '@/lib/admin-api';
import UserDetailPage from './page';

/**
 * Les droits tels que le serveur les rend : TOUS, ceux du plan premium dans
 * l'état donné (sauf exceptions nommées), les autres jamais ouverts.
 */
function droits(
  premium: Omit<ManagedEntitlement, 'key'>,
  exceptions: Partial<Record<string, Omit<ManagedEntitlement, 'key'>>> = {},
): ManagedEntitlement[] {
  return ENTITLEMENT_KEYS.map((key) => ({
    key,
    ...(exceptions[key] ??
      (PREMIUM_ENTITLEMENT_KEYS.includes(key)
        ? premium
        : { isActive: false, expiresAt: null, source: 'NONE' as const })),
  }));
}

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
  entitlements: droits({ isActive: false, expiresAt: null, source: 'NONE' }),
  paidSubscription: null,
};

/** Un abonné Stripe qui paie : l'accès vient de l'abonnement, pas d'une décision manuelle. */
const ABONNE: ManagedUserDetail = {
  ...USER,
  isPremium: true,
  entitlements: droits({
    isActive: true,
    expiresAt: '2026-10-07T10:00:00.000Z',
    source: 'SUBSCRIPTION',
    provider: 'STRIPE',
  }),
  paidSubscription: {
    provider: 'STRIPE',
    status: 'ACTIVE',
    currentPeriodEnd: '2026-10-07T10:00:00.000Z',
    cancelAtPeriodEnd: false,
  },
};

/** Le même, coupé à la main : l'abonnement court toujours, l'accès non. */
const ABONNE_COUPE: ManagedUserDetail = {
  ...ABONNE,
  isPremium: false,
  entitlements: droits({ isActive: false, expiresAt: null, source: 'MANUAL_REVOCATION' }),
};

/**
 * Ce que laissait l'ancienne coupure, qui ne visait que `premium_exercises` :
 * le coach IA, les programmes illimités… suivaient toujours l'abonnement.
 */
const ABONNE_A_DEMI_COUPE: ManagedUserDetail = {
  ...ABONNE,
  isPremium: false,
  entitlements: droits(
    {
      isActive: true,
      expiresAt: '2026-10-07T10:00:00.000Z',
      source: 'SUBSCRIPTION',
      provider: 'STRIPE',
    },
    { premium_exercises: { isActive: false, expiresAt: null, source: 'MANUAL_REVOCATION' } },
  ),
};

/** Offert à la main, sans abonnement : « Rendre la main » refermera l'accès. */
const OFFERT: ManagedUserDetail = {
  ...USER,
  isPremium: true,
  entitlements: droits({ isActive: true, expiresAt: null, source: 'MANUAL_GRANT' }),
};

/** Le rôle qui traite les signalements : ni user:update ni entitlement:grant. */
const SUPPORT = ['user:read', 'audit:read', 'community:moderate'];

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

/** Un super-administrateur connecté : toutes les permissions. */
function connecte(permissions: readonly string[] = ADMIN_PERMISSIONS) {
  adminToken.set('jeton-admin');
  adminPermissions.set(permissions);
}

describe('Fiche utilisateur', () => {
  /**
   * Le seul bouton premium se libellait d'après `isPremium` : un abonné
   * Stripe voyait « Retirer le premium manuel », et un clic coupait un accès
   * PAYÉ, pour toujours, en bloquant tout achat. Trois gestes distincts
   * désormais, et la fiche dit d'où vient l'accès.
   */
  describe('accès premium', () => {
    it('un abonné payant : l’accès vient de l’abonnement, aucun « retirer le premium »', async () => {
      connecte();
      vi.spyOn(adminApi, 'userDetail').mockResolvedValue(ABONNE);

      renderPage();

      expect(await screen.findByText(/Ouvert par l’abonnement Stripe \(web\)/)).toBeInTheDocument();
      expect(screen.getByText(/Abonnement Stripe \(web\) actif/)).toBeInTheDocument();
      expect(screen.queryByRole('button', { name: /retirer le premium/i })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: 'Offrir le premium' })).not.toBeInTheDocument();
      expect(
        screen.queryByRole('button', { name: 'Rendre la main à l’abonnement' }),
      ).not.toBeInTheDocument();
    });

    it('couper l’accès d’un abonné : avertissement de facturation, raison obligatoire', async () => {
      connecte();
      vi.spyOn(adminApi, 'userDetail').mockResolvedValue(ABONNE);
      const setEntitlement = vi.spyOn(adminApi, 'setEntitlement').mockResolvedValue(ABONNE_COUPE);

      renderPage();
      fireEvent.click(await screen.findByRole('button', { name: /couper l’accès/i }));

      expect(screen.getByText(/n’arrête PAS la facturation/)).toBeInTheDocument();
      const confirmer = screen.getByRole('button', { name: 'Confirmer la coupure' });
      expect(confirmer).toBeDisabled();
      fireEvent.change(screen.getByLabelText(/raison/i), { target: { value: '   ' } });
      expect(confirmer).toBeDisabled();

      fireEvent.change(screen.getByLabelText(/raison/i), {
        target: { value: '  Fraude au remboursement  ' },
      });
      fireEvent.click(confirmer);

      // TOUT le plan est coupé, un droit après l'autre, et rien d'autre.
      await waitFor(() => {
        expect(setEntitlement.mock.calls).toEqual(
          PREMIUM_ENTITLEMENT_KEYS.map((key) => [
            USER.id,
            { key, isActive: false, reason: 'Fraude au remboursement' },
          ]),
        );
      });
      // La réponse du serveur s'affiche : coupé à la main, et la facturation
      // qui continue est rappelée. Le bouton activé a disparu avec la
      // confirmation : le focus va au titre, qui annonce le nouvel état.
      expect(await screen.findByText(/la facturation continue/)).toBeInTheDocument();
      await waitFor(() =>
        expect(screen.getByRole('heading', { name: 'Accès premium : fermé' })).toHaveFocus(),
      );
    });

    it('offre le premium à qui ne l’a pas', async () => {
      connecte();
      vi.spyOn(adminApi, 'userDetail').mockResolvedValue(USER);
      const setEntitlement = vi
        .spyOn(adminApi, 'setEntitlement')
        .mockResolvedValue({ ...USER, isPremium: true });

      renderPage();
      fireEvent.click(await screen.findByRole('button', { name: 'Offrir le premium' }));

      // Le coach IA et les programmes illimités s'ouvrent avec le reste.
      await waitFor(() => {
        expect(setEntitlement.mock.calls).toEqual(
          PREMIUM_ENTITLEMENT_KEYS.map((key) => [USER.id, { key, isActive: true }]),
        );
      });
    });

    it('« Rendre la main à l’abonnement » lève une coupure manuelle', async () => {
      connecte();
      vi.spyOn(adminApi, 'userDetail').mockResolvedValue(ABONNE_COUPE);
      const release = vi.spyOn(adminApi, 'releaseEntitlement').mockResolvedValue(ABONNE);

      renderPage();

      expect(await screen.findByText(/Coupé à la main/)).toBeInTheDocument();
      expect(screen.getByText(/l’abonnement payé rouvrira l’accès/)).toBeInTheDocument();
      // Déjà coupé : pas de seconde coupure à proposer.
      expect(screen.queryByRole('button', { name: /couper l’accès/i })).not.toBeInTheDocument();
      fireEvent.click(screen.getByRole('button', { name: 'Rendre la main à l’abonnement' }));

      await waitFor(() =>
        expect(release.mock.calls).toEqual(PREMIUM_ENTITLEMENT_KEYS.map((key) => [USER.id, key])),
      );
      expect(await screen.findByText(/Ouvert par l’abonnement/)).toBeInTheDocument();
    });

    it('un premium offert se rend aussi à l’abonnement', async () => {
      connecte();
      vi.spyOn(adminApi, 'userDetail').mockResolvedValue(OFFERT);

      renderPage();

      expect(await screen.findByText(/Offert à la main/)).toBeInTheDocument();
      expect(screen.getByText(/sans abonnement payé, l’accès se refermera/)).toBeInTheDocument();
      expect(
        screen.getByRole('button', { name: 'Rendre la main à l’abonnement' }),
      ).toBeInTheDocument();
      expect(screen.queryByRole('button', { name: 'Offrir le premium' })).not.toBeInTheDocument();
    });

    /**
     * Trois mutations, une seule alerte. React Query ne vide l'erreur d'une
     * mutation qu'au prochain appel de CELLE-CI : l'échec d'un geste restait
     * affiché sous l'état qu'un AUTRE geste venait d'établir avec succès.
     */
    it('une coupure ratée puis « Rendre la main » réussi : plus aucune alerte d’échec', async () => {
      connecte();
      vi.spyOn(adminApi, 'userDetail').mockResolvedValue(OFFERT);
      vi.spyOn(adminApi, 'setEntitlement').mockRejectedValueOnce(new TypeError('Failed to fetch'));
      vi.spyOn(adminApi, 'releaseEntitlement').mockResolvedValue(USER);

      renderPage();
      fireEvent.click(await screen.findByRole('button', { name: /couper l’accès/i }));
      fireEvent.change(screen.getByLabelText(/raison/i), { target: { value: 'Fraude' } });
      fireEvent.click(screen.getByRole('button', { name: 'Confirmer la coupure' }));
      expect(await screen.findByRole('alert')).toHaveTextContent('Action impossible, réessaie.');

      fireEvent.click(screen.getByRole('button', { name: 'Annuler' }));
      fireEvent.click(screen.getByRole('button', { name: 'Rendre la main à l’abonnement' }));

      expect(await screen.findByText(/Jamais ouvert/)).toBeInTheDocument();
      expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    });

    it('un « Offrir » raté puis l’ouverture de la coupure : l’ancien échec ne reste pas affiché', async () => {
      connecte();
      vi.spyOn(adminApi, 'userDetail').mockResolvedValue({
        ...USER,
        entitlements: droits({ isActive: false, expiresAt: null, source: 'SUBSCRIPTION' }),
      });
      vi.spyOn(adminApi, 'setEntitlement').mockRejectedValueOnce(new ApiError('Erreur', 502));

      renderPage();
      fireEvent.click(await screen.findByRole('button', { name: 'Offrir le premium' }));
      expect(await screen.findByRole('alert')).toHaveTextContent('Action impossible, réessaie.');

      fireEvent.click(screen.getByRole('button', { name: /couper l’accès/i }));

      expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    });

    it('un plan à demi coupé s’annonce « partiel », et la coupure reste offerte pour l’achever', async () => {
      connecte();
      vi.spyOn(adminApi, 'userDetail').mockResolvedValue(ABONNE_A_DEMI_COUPE);

      renderPage();

      expect(
        await screen.findByRole('heading', { name: 'Accès premium : partiel' }),
      ).toBeInTheDocument();
      expect(screen.getByText(/n’ont pas tous le même état/)).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /couper l’accès/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Offrir le premium' })).toBeInTheDocument();
      expect(
        screen.getByRole('button', { name: 'Rendre la main à l’abonnement' }),
      ).toBeInTheDocument();
    });

    it('une coupure interrompue : la fiche relit le serveur et montre ce qui a changé', async () => {
      connecte();
      vi.spyOn(adminApi, 'userDetail')
        .mockResolvedValueOnce(ABONNE)
        .mockResolvedValue(ABONNE_A_DEMI_COUPE);
      vi.spyOn(adminApi, 'setEntitlement')
        .mockResolvedValueOnce(ABONNE_A_DEMI_COUPE)
        .mockRejectedValueOnce(new ApiError('Erreur', 502));

      renderPage();
      fireEvent.click(await screen.findByRole('button', { name: /couper l’accès/i }));
      fireEvent.change(screen.getByLabelText(/raison/i), { target: { value: 'Fraude' } });
      fireEvent.click(screen.getByRole('button', { name: 'Confirmer la coupure' }));

      expect(await screen.findByRole('alert')).toHaveTextContent('Action impossible, réessaie.');
      expect(
        await screen.findByRole('heading', { name: 'Accès premium : partiel' }),
      ).toBeInTheDocument();
    });

    it('le titre ne prend le focus qu’une fois le NOUVEL état affiché', async () => {
      connecte();
      vi.spyOn(adminApi, 'userDetail').mockResolvedValue(ABONNE);
      vi.spyOn(adminApi, 'setEntitlement').mockResolvedValue(ABONNE_COUPE);
      const annonces: string[] = [];

      renderPage();
      const titre = await screen.findByRole('heading', { name: 'Accès premium : ouvert' });
      titre.addEventListener('focus', () => annonces.push(titre.textContent));
      fireEvent.click(screen.getByRole('button', { name: /couper l’accès/i }));
      fireEvent.change(screen.getByLabelText(/raison/i), { target: { value: 'Fraude' } });
      fireEvent.click(screen.getByRole('button', { name: 'Confirmer la coupure' }));

      await waitFor(() => expect(titre).toHaveFocus());
      expect(annonces).toEqual(['Accès premium : fermé']);
    });

    it('le focus suit la coupure : la raison à l’ouverture, le bouton à l’annulation', async () => {
      connecte();
      vi.spyOn(adminApi, 'userDetail').mockResolvedValue(ABONNE);

      renderPage();
      const couper = await screen.findByRole('button', { name: /couper l’accès/i });
      couper.focus();
      fireEvent.click(couper);
      expect(screen.getByLabelText(/raison/i)).toHaveFocus();

      fireEvent.click(screen.getByRole('button', { name: 'Annuler' }));
      expect(screen.getByRole('button', { name: /couper l’accès/i })).toHaveFocus();
    });
  });

  /**
   * Le rôle support traite les signalements, et la page Signalements
   * l'envoyait ici « pour suspendre ». La fiche lui montrait deux boutons
   * actifs que le serveur refusait TOUJOURS (user:update, entitlement:grant).
   */
  it('le support ne voit aucun geste qu’il ne peut pas faire, et sait à qui s’adresser', async () => {
    connecte(SUPPORT);
    vi.spyOn(adminApi, 'userDetail').mockResolvedValue(ABONNE);

    renderPage();

    expect(
      await screen.findByText(/réservé aux administrateurs qui ont la permission user:update/),
    ).toBeInTheDocument();
    expect(screen.getByText(/permission entitlement:grant/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /suspendre/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /couper l’accès/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /offrir/i })).not.toBeInTheDocument();
    // L'état, lui, reste lisible.
    expect(screen.getByText(/Ouvert par l’abonnement/)).toBeInTheDocument();
  });

  it('montre un refus de permission (403) comme tel, pas comme une panne', async () => {
    connecte();
    vi.spyOn(adminApi, 'userDetail').mockResolvedValue(USER);
    vi.spyOn(adminApi, 'setEntitlement').mockRejectedValue(
      new ApiError('Permission entitlement:grant requise.', 403),
    );

    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'Offrir le premium' }));

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('Permission manquante pour cette action.');
    expect(alert).not.toHaveTextContent('Action impossible');
  });

  it('montre une panne serveur comme une action à réessayer', async () => {
    connecte();
    vi.spyOn(adminApi, 'userDetail').mockResolvedValue(USER);
    vi.spyOn(adminApi, 'setUserStatus').mockRejectedValue(new ApiError('Erreur 502', 502));

    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: /suspendre le compte/i }));

    expect(await screen.findByRole('alert')).toHaveTextContent('Action impossible, réessaie.');
  });

  // Le message du serveur diffère volontairement du texte de la page : c'est
  // le STATUT qui doit décider de la phrase affichée, pas le message reçu.
  it('distingue un compte introuvable (404) d’une fiche indisponible', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'userDetail').mockRejectedValue(new ApiError('Not found', 404));

    renderPage();

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('Utilisateur introuvable.');
    expect(alert).not.toHaveTextContent('Fiche indisponible.');
  });

  it('montre toute autre erreur de chargement comme une fiche indisponible', async () => {
    adminToken.set('jeton-admin');
    vi.spyOn(adminApi, 'userDetail').mockRejectedValue(new ApiError('Internal server error', 500));

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
