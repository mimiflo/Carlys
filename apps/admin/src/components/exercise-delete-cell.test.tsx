import { fireEvent, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiError, adminApi } from '@/lib/admin-api';
import { DEVELOPPE_COUCHE, exercise, inRow, renderWithQuery } from '@/testing/fixtures';
import { ExerciseDeleteCell } from './exercise-delete-cell';

/**
 * Retirer un exercice du catalogue passe par une confirmation, se défait par
 * « Restaurer », et garde le focus clavier à l'endroit du geste : chaque
 * étape DÉMONTE le bouton qu'on vient d'activer.
 */

const SUPPRIME = exercise({ deletedAt: '2026-09-20T08:00:00.000Z' });

afterEach(() => {
  vi.restoreAllMocks();
});

describe('ExerciseDeleteCell', () => {
  it('« Supprimer » demande confirmation avant tout appel', () => {
    const remove = vi.spyOn(adminApi, 'deleteExercise').mockResolvedValue(undefined);
    renderWithQuery(inRow(<ExerciseDeleteCell exercise={DEVELOPPE_COUCHE} />));

    fireEvent.click(screen.getByRole('button', { name: 'Supprimer' }));

    expect(screen.getByText(/l’historique des séances qui le citent reste intact/)).toBeVisible();
    expect(remove).not.toHaveBeenCalled();
  });

  it('« Confirmer » retire l’exercice', async () => {
    const remove = vi.spyOn(adminApi, 'deleteExercise').mockResolvedValue(undefined);
    renderWithQuery(inRow(<ExerciseDeleteCell exercise={DEVELOPPE_COUCHE} />));

    fireEvent.click(screen.getByRole('button', { name: 'Supprimer' }));
    fireEvent.click(screen.getByRole('button', { name: 'Confirmer' }));

    await waitFor(() => expect(remove).toHaveBeenCalledWith(DEVELOPPE_COUCHE.id));
  });

  it('un exercice supprimé se restaure, sans confirmation', async () => {
    const restore = vi.spyOn(adminApi, 'restoreExercise').mockResolvedValue(undefined);
    renderWithQuery(inRow(<ExerciseDeleteCell exercise={SUPPRIME} />));

    expect(screen.getByText(/Supprimé le/)).toBeVisible();
    fireEvent.click(screen.getByRole('button', { name: 'Restaurer' }));

    await waitFor(() => expect(restore).toHaveBeenCalledWith(SUPPRIME.id));
  });

  it('un refus du serveur s’affiche, la confirmation reste ouverte', async () => {
    vi.spyOn(adminApi, 'deleteExercise').mockRejectedValue(
      new ApiError('Exercice introuvable.', 404),
    );
    renderWithQuery(inRow(<ExerciseDeleteCell exercise={DEVELOPPE_COUCHE} />));

    fireEvent.click(screen.getByRole('button', { name: 'Supprimer' }));
    fireEvent.click(screen.getByRole('button', { name: 'Confirmer' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('Exercice introuvable.');
    expect(screen.getByRole('button', { name: 'Confirmer' })).toBeEnabled();
  });

  describe('focus clavier', () => {
    it('« Supprimer » le pose sur « Annuler », jamais sur le geste destructeur', () => {
      renderWithQuery(inRow(<ExerciseDeleteCell exercise={DEVELOPPE_COUCHE} />));
      const supprimer = screen.getByRole('button', { name: 'Supprimer' });
      supprimer.focus();

      fireEvent.click(supprimer);

      expect(screen.getByRole('button', { name: 'Annuler' })).toHaveFocus();
    });

    it('« Annuler » le rend à « Supprimer »', () => {
      renderWithQuery(inRow(<ExerciseDeleteCell exercise={DEVELOPPE_COUCHE} />));
      fireEvent.click(screen.getByRole('button', { name: 'Supprimer' }));

      fireEvent.click(screen.getByRole('button', { name: 'Annuler' }));

      expect(screen.getByRole('button', { name: 'Supprimer' })).toHaveFocus();
    });

    /**
     * L'ordre réel de React Query : `invalidateQueries` se résout, et la liste
     * rafraîchie n'est livrée aux composants qu'ensuite, dans un
     * `setTimeout(0)`. Entre les deux, la cellule remontre « Supprimer » avec
     * l'ancienne donnée : le focus ne doit pas s'y poser, puisque ce bouton
     * disparaît dès que la liste arrive.
     */
    async function supprimeSansListeRafraichie() {
      vi.spyOn(adminApi, 'deleteExercise').mockResolvedValue(undefined);
      const rendu = renderWithQuery(inRow(<ExerciseDeleteCell exercise={DEVELOPPE_COUCHE} />));
      vi.spyOn(rendu.client, 'invalidateQueries').mockResolvedValue(undefined);
      const supprimer = screen.getByRole('button', { name: 'Supprimer' });
      supprimer.focus();
      fireEvent.click(supprimer);
      fireEvent.click(screen.getByRole('button', { name: 'Confirmer' }));
      const perime = await screen.findByRole('button', { name: 'Supprimer' });
      return { ...rendu, perime };
    }

    it('après la suppression, il attend « Restaurer », même quand la liste arrive APRÈS', async () => {
      const { perime, rerenderWith } = await supprimeSansListeRafraichie();
      expect(perime).not.toHaveFocus();

      rerenderWith(inRow(<ExerciseDeleteCell exercise={SUPPRIME} />));

      expect(screen.getByRole('button', { name: 'Restaurer' })).toHaveFocus();
    });

    it('après la suppression, il va à « Restaurer » quand la liste arrive AVANT', async () => {
      vi.spyOn(adminApi, 'deleteExercise').mockResolvedValue(undefined);
      const { client, rerenderWith } = renderWithQuery(
        inRow(<ExerciseDeleteCell exercise={DEVELOPPE_COUCHE} />),
      );
      vi.spyOn(client, 'invalidateQueries').mockImplementation(() => {
        rerenderWith(inRow(<ExerciseDeleteCell exercise={SUPPRIME} />));
        return Promise.resolve();
      });

      fireEvent.click(screen.getByRole('button', { name: 'Supprimer' }));
      fireEvent.click(screen.getByRole('button', { name: 'Confirmer' }));

      await waitFor(() => expect(screen.getByRole('button', { name: 'Restaurer' })).toHaveFocus());
    });

    it('une demande en attente ne reprend pas le focus posé ailleurs entre-temps', async () => {
      const { rerenderWith } = await supprimeSansListeRafraichie();
      const ailleurs = document.createElement('input');
      document.body.append(ailleurs);
      ailleurs.focus();

      rerenderWith(inRow(<ExerciseDeleteCell exercise={SUPPRIME} />));

      expect(ailleurs).toHaveFocus();
      ailleurs.remove();
    });

    it('une demande ne se sert qu’une fois : un aller-retour de la liste ne la rejoue pas', async () => {
      const { rerenderWith } = await supprimeSansListeRafraichie();
      rerenderWith(inRow(<ExerciseDeleteCell exercise={SUPPRIME} />));
      const restaurer = screen.getByRole('button', { name: 'Restaurer' });
      expect(restaurer).toHaveFocus();
      restaurer.blur();

      rerenderWith(inRow(<ExerciseDeleteCell exercise={DEVELOPPE_COUCHE} />));
      rerenderWith(inRow(<ExerciseDeleteCell exercise={SUPPRIME} />));

      expect(screen.getByRole('button', { name: 'Restaurer' })).not.toHaveFocus();
    });

    it('un rafraîchissement sans geste ne vole jamais le focus', () => {
      const { rerenderWith } = renderWithQuery(
        inRow(<ExerciseDeleteCell exercise={DEVELOPPE_COUCHE} />),
      );
      const ailleurs = document.createElement('button');
      document.body.append(ailleurs);
      ailleurs.focus();

      rerenderWith(inRow(<ExerciseDeleteCell exercise={SUPPRIME} />));

      expect(ailleurs).toHaveFocus();
      ailleurs.remove();
    });
  });
});
