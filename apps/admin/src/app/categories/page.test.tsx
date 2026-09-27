import { ADMIN_PERMISSIONS } from '@carlys/api-contracts';
import { fireEvent, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AdminApiError, adminApi, adminPermissions, adminToken } from '@/lib/admin-api';
import { MUSCLE_GROUPS, renderWithQuery } from '@/testing/fixtures';
import CategoriesPage from './page';

/**
 * Les catégories du catalogue : la liste avec ce que chaque groupe emporte,
 * la création avec un slug proposé d'après le nom, et les refus dits pour
 * ce qu'ils sont.
 */

vi.mock('next/navigation', () => ({
  usePathname: () => '/categories',
  useRouter: () => ({ replace: vi.fn(), push: vi.fn() }),
}));

beforeEach(() => {
  adminToken.set('jeton-admin');
  adminPermissions.set(ADMIN_PERMISSIONS);
});

afterEach(() => {
  vi.restoreAllMocks();
  adminToken.clear();
});

describe('Page Catégories', () => {
  it('liste chaque groupe avec le nombre d’exercices qu’il emporte', async () => {
    vi.spyOn(adminApi, 'listMuscleGroups').mockResolvedValue(MUSCLE_GROUPS);

    renderWithQuery(<CategoriesPage />);

    expect(await screen.findByText('Pectoraux')).toBeInTheDocument();
    expect(screen.getByText('12 dont 8 en principal')).toBeInTheDocument();
    // Un groupe encore principal quelque part ne se supprime pas : le serveur
    // rendrait 409, le bouton ne le propose donc pas.
    const [supprimerPectoraux] = screen.getAllByRole('button', { name: 'Supprimer' });
    expect(supprimerPectoraux).toBeDisabled();
  });

  it('crée une catégorie avec le slug proposé d’après le nom', async () => {
    vi.spyOn(adminApi, 'listMuscleGroups').mockResolvedValue(MUSCLE_GROUPS);
    const create = vi.spyOn(adminApi, 'createMuscleGroup').mockResolvedValue({
      id: 'dddddddd-2222-4333-8444-555555555555',
      slug: 'trapezes',
      name: 'Trapèzes',
      sortOrder: 0,
      exercisesCount: 0,
      primaryExercisesCount: 0,
    });

    renderWithQuery(<CategoriesPage />);
    await screen.findByText('Pectoraux');
    fireEvent.change(screen.getByPlaceholderText('Trapèzes'), { target: { value: 'Trapèzes' } });
    fireEvent.click(screen.getByRole('button', { name: 'Ajouter' }));

    await waitFor(() =>
      expect(create).toHaveBeenCalledWith({ slug: 'trapezes', name: 'Trapèzes' }),
    );
  });

  it('dit « Aucune catégorie. » sur une base vide', async () => {
    vi.spyOn(adminApi, 'listMuscleGroups').mockResolvedValue([]);

    renderWithQuery(<CategoriesPage />);

    expect(await screen.findByText('Aucune catégorie.')).toBeInTheDocument();
  });

  it('une panne n’est pas présentée comme un problème de session', async () => {
    vi.spyOn(adminApi, 'listMuscleGroups').mockRejectedValue(new AdminApiError('Erreur 502', 502));

    renderWithQuery(<CategoriesPage />);

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('Catégories indisponibles pour le moment.');
    expect(alert).not.toHaveTextContent(/reconnect/);
  });
});
