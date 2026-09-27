import type { AdminExerciseSummary } from '@carlys/api-contracts';
import { ADMIN_PERMISSIONS } from '@carlys/api-contracts';
import { fireEvent, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AdminApiError, adminApi, adminPermissions, adminToken, type Page } from '@/lib/admin-api';
import { exercise, renderWithQuery } from '@/testing/fixtures';
import ExercisesPage from './page';

/**
 * La page ne demandait QUE la première page du catalogue : la route en sert
 * cinquante, le catalogue en compte près de deux cents, et les autres
 * n'étaient atteignables qu'en tapant leur nom. Passer en revue les
 * exercices sans photo ou masqués était impossible.
 */

vi.mock('next/navigation', () => ({
  usePathname: () => '/exercises',
  useRouter: () => ({ replace: vi.fn(), push: vi.fn() }),
}));

function numero(index: number): AdminExerciseSummary {
  return exercise({
    id: `${index}`.padStart(8, '0') + '-2222-4333-8444-555555555555',
    slug: `exercice-${index}`,
    name: `Exercice ${index}`,
  });
}

function pageOf(
  items: AdminExerciseSummary[],
  nextCursor: string | null = null,
): Page<AdminExerciseSummary> {
  return { items, nextCursor, hasMore: nextCursor !== null };
}

beforeEach(() => {
  adminToken.set('jeton-admin');
  adminPermissions.set(ADMIN_PERMISSIONS);
});

afterEach(() => {
  vi.restoreAllMocks();
  adminToken.clear();
});

describe('Page Exercices', () => {
  it('« Charger la suite » va chercher la page suivante et l’ajoute au tableau', async () => {
    const list = vi
      .spyOn(adminApi, 'listExercises')
      .mockResolvedValueOnce(pageOf([numero(1), numero(2)], 'curseur-page-2'))
      .mockResolvedValueOnce(pageOf([numero(51)]));

    renderWithQuery(<ExercisesPage />);
    await screen.findByText('Exercice 1');

    fireEvent.click(screen.getByRole('button', { name: 'Charger la suite' }));

    expect(await screen.findByText('Exercice 51')).toBeInTheDocument();
    // Les exercices déjà lus restent : on empile, on ne remplace pas.
    expect(screen.getByText('Exercice 1')).toBeInTheDocument();
    expect(list).toHaveBeenLastCalledWith(undefined, 'curseur-page-2', false);
    expect(screen.queryByRole('button', { name: 'Charger la suite' })).not.toBeInTheDocument();
  });

  it('« Voir les supprimés » repart de la première page, supprimés compris', async () => {
    const list = vi.spyOn(adminApi, 'listExercises').mockResolvedValue(pageOf([numero(1)]));

    renderWithQuery(<ExercisesPage />);
    await screen.findByText('Exercice 1');
    fireEvent.click(screen.getByRole('checkbox', { name: 'Voir les supprimés' }));

    await waitFor(() => expect(list).toHaveBeenLastCalledWith(undefined, undefined, true));
  });

  it('une recherche repart de la PREMIÈRE page, sans curseur', async () => {
    const list = vi.spyOn(adminApi, 'listExercises').mockResolvedValue(pageOf([numero(1)]));

    renderWithQuery(<ExercisesPage />);
    await screen.findByText('Exercice 1');
    fireEvent.change(screen.getByLabelText('Rechercher un exercice'), {
      target: { value: '  squat ' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Rechercher' }));

    await waitFor(() => expect(list).toHaveBeenLastCalledWith('squat', undefined, false));
  });

  it('dit « Aucun exercice trouvé » sur toute la largeur, sans bouton de suite', async () => {
    vi.spyOn(adminApi, 'listExercises').mockResolvedValue(pageOf([]));

    renderWithQuery(<ExercisesPage />);

    const vide = await screen.findByText('Aucun exercice trouvé.');
    expect(vide).toHaveAttribute('colspan', String(screen.getAllByRole('columnheader').length));
    expect(screen.queryByRole('button', { name: 'Charger la suite' })).not.toBeInTheDocument();
  });

  /**
   * La vraie page et le vrai React Query, supprimés visibles : c'est la liste
   * RAFRAÎCHIE qui fait paraître « Restaurer » (puis « Supprimer »), et
   * React Query la livre après la fin de `invalidateQueries`. Le focus
   * retombait sur `<body>` : il allait à l'ancien bouton, démonté aussitôt.
   */
  describe('focus clavier après suppression et restauration', () => {
    let serveur: AdminExerciseSummary;

    beforeEach(() => {
      serveur = exercise();
      vi.spyOn(adminApi, 'listExercises').mockImplementation((_search, _cursor, withDeleted) =>
        Promise.resolve(
          pageOf(withDeleted === true || serveur.deletedAt === null ? [{ ...serveur }] : []),
        ),
      );
      vi.spyOn(adminApi, 'deleteExercise').mockImplementation(() => {
        serveur = { ...serveur, deletedAt: '2026-09-20T08:00:00.000Z' };
        return Promise.resolve(undefined);
      });
      vi.spyOn(adminApi, 'restoreExercise').mockImplementation(() => {
        serveur = { ...serveur, deletedAt: null };
        return Promise.resolve(undefined);
      });
    });

    async function avecLesSupprimes() {
      renderWithQuery(<ExercisesPage />);
      fireEvent.click(screen.getByRole('checkbox', { name: 'Voir les supprimés' }));
      await screen.findByText('Développé couché');
    }

    it('après « Confirmer », il va à « Restaurer »', async () => {
      await avecLesSupprimes();
      const supprimer = await screen.findByRole('button', { name: 'Supprimer' });
      supprimer.focus();
      fireEvent.click(supprimer);

      fireEvent.click(screen.getByRole('button', { name: 'Confirmer' }));

      const restaurer = await screen.findByRole('button', { name: 'Restaurer' });
      await waitFor(() => expect(restaurer).toHaveFocus());
    });

    it('après « Restaurer », il va à « Supprimer »', async () => {
      serveur = { ...serveur, deletedAt: '2026-09-20T08:00:00.000Z' };
      await avecLesSupprimes();
      const restaurer = await screen.findByRole('button', { name: 'Restaurer' });
      restaurer.focus();

      fireEvent.click(restaurer);

      const supprimer = await screen.findByRole('button', { name: 'Supprimer' });
      await waitFor(() => expect(supprimer).toHaveFocus());
    });
  });

  it('un refus de permission (403) se dit comme tel', async () => {
    vi.spyOn(adminApi, 'listExercises').mockRejectedValue(new AdminApiError('Refus.', 403));

    renderWithQuery(<ExercisesPage />);

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Catalogue indisponible : la permission exercise:read est requise.',
    );
  });
});
