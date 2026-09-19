import type { AdminMuscleGroup } from '@carlys/api-contracts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { adminApi } from '@/lib/admin-api';
import { CategoryRow } from './category-row';

/**
 * « Annuler » ne faisait que refermer les champs : le brouillon abandonné
 * restait en mémoire. Rouvrir « Modifier » puis enregistrer réécrivait le
 * renommage qu'on venait d'annuler — et, si la liste avait entre-temps
 * rapporté le renommage d'un AUTRE administrateur, ce brouillon périmé
 * écrasait son travail sans un mot.
 */

const PECTORAUX: AdminMuscleGroup = {
  id: '11111111-2222-4333-8444-555555555555',
  slug: 'pectoraux',
  name: 'Pectoraux',
  sortOrder: 3,
  exercisesCount: 12,
  primaryExercisesCount: 0,
};

function renderRow(group: AdminMuscleGroup = PECTORAUX) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <table>
        <tbody>
          <CategoryRow group={group} />
        </tbody>
      </table>
    </QueryClientProvider>,
  );
}

afterEach(() => {
  vi.restoreAllMocks();
});

describe('CategoryRow', () => {
  it('« Annuler » rend le brouillon, il ne se contente pas de refermer', () => {
    renderRow();

    fireEvent.click(screen.getByRole('button', { name: 'Modifier' }));
    fireEvent.change(screen.getByLabelText('Nom de Pectoraux'), {
      target: { value: 'Pecs (essai)' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Annuler' }));
    fireEvent.click(screen.getByRole('button', { name: 'Modifier' }));

    expect(screen.getByLabelText('Nom de Pectoraux')).toHaveValue('Pectoraux');
  });

  it('rouvrir reprend ce que la LISTE affiche, pas une saisie périmée', () => {
    // La liste vient d'être rafraîchie : un autre administrateur a renommé.
    const { rerender } = renderRow();
    fireEvent.click(screen.getByRole('button', { name: 'Modifier' }));
    fireEvent.change(screen.getByLabelText('Nom de Pectoraux'), {
      target: { value: 'Mon brouillon' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Annuler' }));

    const renomme = { ...PECTORAUX, name: 'Poitrine' };
    const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    rerender(
      <QueryClientProvider client={queryClient}>
        <table>
          <tbody>
            <CategoryRow group={renomme} />
          </tbody>
        </table>
      </QueryClientProvider>,
    );
    fireEvent.click(screen.getByRole('button', { name: 'Modifier' }));

    expect(screen.getByLabelText('Nom de Poitrine')).toHaveValue('Poitrine');
  });

  it('enregistrer envoie ce qui est à l’écran', async () => {
    const update = vi.spyOn(adminApi, 'updateMuscleGroup').mockResolvedValue(undefined);
    renderRow();

    fireEvent.click(screen.getByRole('button', { name: 'Modifier' }));
    fireEvent.change(screen.getByLabelText('Nom de Pectoraux'), { target: { value: 'Poitrine' } });
    fireEvent.click(screen.getByRole('button', { name: 'Enregistrer' }));

    await waitFor(() =>
      expect(update).toHaveBeenCalledWith(PECTORAUX.id, { name: 'Poitrine', sortOrder: 3 }),
    );
  });
});
