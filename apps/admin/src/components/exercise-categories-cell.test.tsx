import { fireEvent, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { adminApi } from '@/lib/admin-api';
import {
  DEVELOPPE_COUCHE,
  EQUIPMENT,
  MUSCLE_GROUPS,
  exercise,
  inRow,
  renderWithQuery,
} from '@/testing/fixtures';
import { ExerciseCategoriesCell } from './exercise-categories-cell';

/**
 * Le brouillon de reclassement n'était lu qu'au MONTAGE de la cellule.
 * Cocher « Triceps », annuler, rouvrir : Triceps restait coché, et
 * « Enregistrer » écrivait le choix annulé. Et quand la liste rapportait le
 * reclassement d'un autre administrateur, l'éditeur rouvert montrait l'état
 * d'avant : enregistrer écrasait son travail sans un mot. `CategoryRow`
 * avait déjà reçu ce correctif, pas cette cellule.
 */

beforeEach(() => {
  vi.spyOn(adminApi, 'listMuscleGroups').mockResolvedValue(MUSCLE_GROUPS);
  vi.spyOn(adminApi, 'listEquipment').mockResolvedValue(EQUIPMENT);
});

afterEach(() => {
  vi.restoreAllMocks();
});

async function openEditor() {
  fireEvent.click(screen.getByRole('button', { name: /modifier/i }));
  return screen.findByRole('checkbox', { name: 'Triceps' });
}

describe('ExerciseCategoriesCell — brouillon', () => {
  it('« Annuler » rend le brouillon : rouvrir ne ressuscite pas le choix annulé', async () => {
    renderWithQuery(inRow(<ExerciseCategoriesCell exercise={DEVELOPPE_COUCHE} />));

    fireEvent.click(await openEditor());
    expect(screen.getByRole('checkbox', { name: 'Triceps' })).toBeChecked();
    fireEvent.click(screen.getByRole('button', { name: 'Annuler' }));

    expect(await openEditor()).not.toBeChecked();
  });

  it('rouvrir reprend ce que la LISTE affiche, pas l’état du montage', async () => {
    const { rerenderWith } = renderWithQuery(
      inRow(<ExerciseCategoriesCell exercise={DEVELOPPE_COUCHE} />),
    );
    await openEditor();
    fireEvent.click(screen.getByRole('button', { name: 'Annuler' }));

    // La liste vient d'être rafraîchie : un autre administrateur a ajouté triceps.
    const reclasse = exercise({ muscleGroupSlugs: ['pectoraux', 'triceps'] });
    rerenderWith(inRow(<ExerciseCategoriesCell exercise={reclasse} />));

    expect(await openEditor()).toBeChecked();
  });

  it('enregistrer envoie ce qui est à l’écran, principal exclu des secondaires', async () => {
    const save = vi
      .spyOn(adminApi, 'setExerciseCategories')
      .mockResolvedValue(exercise({ muscleGroupSlugs: ['pectoraux', 'triceps'] }));
    renderWithQuery(inRow(<ExerciseCategoriesCell exercise={DEVELOPPE_COUCHE} />));

    fireEvent.click(await openEditor());
    fireEvent.click(screen.getByRole('checkbox', { name: 'Barre' }));
    fireEvent.click(screen.getByRole('button', { name: 'Enregistrer' }));

    await waitFor(() =>
      expect(save).toHaveBeenCalledWith(DEVELOPPE_COUCHE.id, {
        primaryMuscleGroupSlug: 'pectoraux',
        secondaryMuscleGroupSlugs: ['triceps'],
        equipmentSlugs: ['barre'],
      }),
    );
  });

  it('dit que les référentiels manquent, au lieu d’un éditeur vide', async () => {
    vi.spyOn(adminApi, 'listMuscleGroups').mockRejectedValue(new Error('panne'));
    renderWithQuery(inRow(<ExerciseCategoriesCell exercise={DEVELOPPE_COUCHE} />));

    fireEvent.click(screen.getByRole('button', { name: /modifier/i }));

    expect(await screen.findByRole('alert')).toHaveTextContent('Référentiels indisponibles.');
  });
});

describe('ExerciseCategoriesCell — focus clavier', () => {
  it('ouvrir pose le focus sur l’éditeur, annuler le rend au bouton d’origine', async () => {
    renderWithQuery(inRow(<ExerciseCategoriesCell exercise={DEVELOPPE_COUCHE} />));
    const opener = screen.getByRole('button', { name: /modifier/i });
    opener.focus();

    fireEvent.click(opener);
    expect(screen.getByRole('group', { name: 'Catégories de Développé couché' })).toHaveFocus();

    await screen.findByRole('checkbox', { name: 'Triceps' });
    fireEvent.click(screen.getByRole('button', { name: 'Annuler' }));
    expect(screen.getByRole('button', { name: /modifier/i })).toHaveFocus();
  });
});
