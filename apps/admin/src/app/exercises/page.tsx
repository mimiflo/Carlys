'use client';

import { type AdminExerciseSummary } from '@carlys/api-contracts';
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { AdminShell } from '@/components/admin-shell';
import { ExerciseCategoriesCell } from '@/components/exercise-categories-cell';
import { ExerciseDeleteCell } from '@/components/exercise-delete-cell';
import { ExercisePhotoCell } from '@/components/exercise-photo-cell';
import { button } from '@/components/ui/button';
import { SearchForm } from '@/components/ui/search-form';
import { ErrorState, SkeletonRows } from '@/components/ui/states';
import { TableCard, td, th, thead, tr } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { adminApi } from '@/lib/admin-api';
import { planStatus } from '@/lib/status-labels';
import { unavailableMessage } from '@/lib/load-error';

function PublicationToggle({ exercise }: { exercise: AdminExerciseSummary }) {
  const queryClient = useQueryClient();
  const toggle = useMutation({
    mutationFn: () => adminApi.setExercisePublication(exercise.id, !exercise.isPublished),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin', 'exercises'] }),
  });

  if (exercise.deletedAt !== null) {
    return <span className="text-xs text-muted">Supprimé</span>;
  }

  return (
    <button
      type="button"
      disabled={toggle.isPending}
      onClick={() => toggle.mutate()}
      aria-pressed={exercise.isPublished}
      title={exercise.isPublished ? 'Masquer du catalogue' : 'Publier dans le catalogue'}
      className={`inline-flex h-6 items-center gap-1.5 rounded-full px-2.5 text-xs font-medium transition-[background-color,box-shadow] duration-150 hover:ring-1 hover:ring-primary/40 disabled:opacity-50 ${
        exercise.isPublished ? 'bg-success/12 text-foreground' : 'bg-foreground/6 text-muted'
      }`}
    >
      <span
        aria-hidden
        className={`h-1.5 w-1.5 rounded-full ${exercise.isPublished ? 'bg-success' : 'bg-muted'}`}
      />
      {exercise.isPublished ? 'Publié' : 'Masqué'}
    </button>
  );
}

/**
 * Catalogue vu du back-office.
 *
 * **Tout média passe par ici** : les photos d'exercices ne sont pas embarquées
 * dans l'application, elles sont déposées depuis cet écran et servies par le
 * stockage objet. Ajouter une illustration ne demande donc aucune livraison.
 *
 * Page par page, comme les utilisateurs. La page ne demandait QUE la
 * première : la route en sert cinquante, le catalogue en compte près de
 * deux cents, et les autres n'étaient atteignables qu'en tapant leur nom.
 * Passer en revue les exercices sans photo ou masqués était impossible.
 */
export default function ExercisesPage() {
  const [submitted, setSubmitted] = useState('');
  const [includeDeleted, setIncludeDeleted] = useState(false);
  const { data, isPending, error, fetchNextPage, hasNextPage, isFetchingNextPage, refetch } =
    useInfiniteQuery({
      queryKey: ['admin', 'exercises', submitted, includeDeleted],
      queryFn: ({ pageParam }) =>
        adminApi.listExercises(submitted === '' ? undefined : submitted, pageParam, includeDeleted),
      initialPageParam: undefined as string | undefined,
      getNextPageParam: (last) =>
        last.hasMore && last.nextCursor !== null ? last.nextCursor : undefined,
    });
  const exercises = data?.pages.flatMap((page) => page.items) ?? [];

  return (
    <AdminShell
      title="Exercices"
      description="Les photos déposées ici sont servies directement aux applications : elles apparaissent à la requête suivante, sans mise à jour de l’app."
    >
      <SearchForm
        label="Rechercher un exercice"
        placeholder="Rechercher un exercice…"
        onSubmit={setSubmitted}
      >
        <label className="flex items-center gap-2 text-sm text-muted">
          <input
            type="checkbox"
            checked={includeDeleted}
            onChange={(event) => setIncludeDeleted(event.target.checked)}
            className="h-4 w-4 accent-primary"
          />
          Voir les supprimés
        </label>
      </SearchForm>

      <div className="mt-6">
        {isPending && <SkeletonRows />}
        {error !== null && (
          <ErrorState onRetry={() => void refetch()}>
            {unavailableMessage(error, 'Catalogue indisponible', 'exercise:read')}
          </ErrorState>
        )}
        {data !== undefined && (
          <TableCard>
            <thead className={thead}>
              <tr>
                <th className={th}>Exercice</th>
                <th className={th}>Catégories</th>
                <th className={th}>Photo</th>
                <th className={th}>Catalogue</th>
                <th className={th}>Retrait</th>
              </tr>
            </thead>
            <tbody>
              {exercises.map((exercise) => (
                <tr key={exercise.id} className={tr}>
                  <td className={td}>
                    {/* Un exercice supprimé se BARRE, il ne pâlit pas : à
                        60 % d'opacité, son slug tombait à 2,17:1 et le
                        bouton « Restaurer », toujours actif, à 2,62. */}
                    <span
                      className={`font-medium ${exercise.deletedAt === null ? '' : 'line-through'}`}
                    >
                      {exercise.name}
                    </span>
                    {exercise.isPremium && (
                      <span className="ml-2 align-middle">
                        <Badge status={planStatus(true)} />
                      </span>
                    )}
                    <span className="block font-mono text-xs text-muted">{exercise.slug}</span>
                  </td>
                  <td className={td}>
                    <ExerciseCategoriesCell exercise={exercise} />
                  </td>
                  <td className={td}>
                    <ExercisePhotoCell exercise={exercise} />
                  </td>
                  <td className={td}>
                    <PublicationToggle exercise={exercise} />
                  </td>
                  <td className={td}>
                    <ExerciseDeleteCell exercise={exercise} />
                  </td>
                </tr>
              ))}
              {exercises.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-12 text-center text-sm text-muted">
                    Aucun exercice trouvé.
                  </td>
                </tr>
              )}
            </tbody>
          </TableCard>
        )}
        {hasNextPage && (
          <button
            type="button"
            onClick={() => void fetchNextPage()}
            disabled={isFetchingNextPage}
            className={`${button('secondary')} mt-4`}
          >
            {isFetchingNextPage ? 'Chargement…' : 'Charger la suite'}
          </button>
        )}
      </div>
    </AdminShell>
  );
}
