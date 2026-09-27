import type { AdminExerciseSummary, AdminMuscleGroup, Equipment } from '@carlys/api-contracts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render } from '@testing-library/react';
import type { ReactElement } from 'react';

/**
 * Données et rendu partagés par les tests du catalogue. Rien ici n'est
 * importé par l'application : ce sont des jeux d'essai, isolés et
 * remplaçables.
 */

export const DEVELOPPE_COUCHE: AdminExerciseSummary = {
  id: '11111111-2222-4333-8444-555555555555',
  slug: 'developpe-couche',
  name: 'Développé couché',
  isPublished: true,
  isPremium: false,
  primaryMuscleGroupName: 'Pectoraux',
  muscleGroupSlugs: ['pectoraux'],
  primaryMuscleGroupSlug: 'pectoraux',
  equipmentSlugs: [],
  deletedAt: null,
  image: null,
  mesh: null,
};

export function exercise(overrides: Partial<AdminExerciseSummary> = {}): AdminExerciseSummary {
  return { ...DEVELOPPE_COUCHE, ...overrides };
}

export const MUSCLE_GROUPS: AdminMuscleGroup[] = [
  {
    id: 'aaaaaaaa-2222-4333-8444-555555555555',
    slug: 'pectoraux',
    name: 'Pectoraux',
    sortOrder: 1,
    exercisesCount: 12,
    primaryExercisesCount: 8,
  },
  {
    id: 'bbbbbbbb-2222-4333-8444-555555555555',
    slug: 'triceps',
    name: 'Triceps',
    sortOrder: 2,
    exercisesCount: 9,
    primaryExercisesCount: 5,
  },
];

export const EQUIPMENT: Equipment[] = [
  { id: 'cccccccc-2222-4333-8444-555555555555', slug: 'barre', name: 'Barre' },
];

/** Sans nouvelle tentative : un échec doit se voir tout de suite, pas après un délai. */
export function testQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
}

/** Rend `ui` sous un client de requêtes neuf, et rend de quoi le re-rendre sous le MÊME. */
export function renderWithQuery(ui: ReactElement) {
  const client = testQueryClient();
  const wrap = (element: ReactElement) => (
    <QueryClientProvider client={client}>{element}</QueryClientProvider>
  );
  const result = render(wrap(ui));
  return {
    ...result,
    client,
    rerenderWith: (element: ReactElement) => result.rerender(wrap(element)),
  };
}

/** Une cellule de table doit vivre dans une table, sans quoi le DOM la déplace. */
export function inRow(cell: ReactElement): ReactElement {
  return (
    <table>
      <tbody>
        <tr>
          <td>{cell}</td>
        </tr>
      </tbody>
    </table>
  );
}
